use axum::{extract::State, http::StatusCode, routing::get, Json, Router};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, env, net::SocketAddr, sync::Arc, time::Duration};

#[derive(Clone)]
struct Registry {
    name: String,
    upstream_url: String,
    catalog_base: String,
}

#[derive(Clone)]
struct AppState {
    registries: Vec<Registry>,
    client: Client,
}

#[derive(Deserialize)]
struct CatalogResponse {
    repositories: Option<Vec<String>>,
}

#[derive(Deserialize)]
struct TagsResponse {
    tags: Option<Vec<String>>,
}

#[derive(Serialize)]
struct RegistryInfo {
    url: String,
    images: usize,
    repositories: Vec<RepoInfo>,
}

#[derive(Serialize)]
struct RepoInfo {
    name: String,
    tags: Vec<String>,
}

#[derive(Serialize)]
struct FullResponse {
    registries: BTreeMap<String, RegistryInfo>,
    summary: BTreeMap<String, serde_json::Value>,
}

#[derive(Serialize)]
struct SummaryResponse {
    summary: BTreeMap<String, serde_json::Value>,
}

fn parse_registries() -> Vec<Registry> {
    let val = env::var("REGISTRIES").unwrap_or_default();
    val.split(',')
        .filter(|s| !s.is_empty())
        .filter_map(|entry| {
            let (name, url) = entry.split_once('=')?;
            Some(Registry {
                name: name.trim().to_string(),
                upstream_url: url.trim().to_string(),
                catalog_base: format!("http://{}:5000", name.trim()),
            })
        })
        .collect()
}

async fn fetch_all_repos(client: &Client, base: &str) -> Option<Vec<String>> {
    let mut repos = Vec::new();
    let mut url = format!("{}/v2/_catalog?n=1000", base);

    loop {
        let resp = client.get(&url).send().await.ok()?;
        let link_header = resp
            .headers()
            .get("link")
            .and_then(|v| v.to_str().ok())
            .map(String::from);

        let catalog: CatalogResponse = resp.json().await.ok()?;
        if let Some(r) = catalog.repositories {
            repos.extend(r);
        }

        match parse_next_link(link_header.as_deref(), base) {
            Some(next) => url = next,
            None => break,
        }
    }

    Some(repos)
}

fn parse_next_link(header: Option<&str>, base: &str) -> Option<String> {
    let header = header?;
    // Link header format: </v2/_catalog?n=100&last=foo>; rel="next"
    if !header.contains("rel=\"next\"") {
        return None;
    }
    let start = header.find('<')?;
    let end = header.find('>')?;
    let path = &header[start + 1..end];
    Some(format!("{}{}", base, path))
}

async fn fetch_tags(client: &Client, base: &str, repo: &str) -> Vec<String> {
    let url = format!("{}/v2/{}/tags/list", base, repo);
    let resp = match client.get(&url).send().await {
        Ok(r) => r,
        Err(_) => return Vec::new(),
    };
    let tags: TagsResponse = match resp.json().await {
        Ok(t) => t,
        Err(_) => return Vec::new(),
    };
    tags.tags.unwrap_or_default()
}

async fn query_registry(client: &Client, registry: &Registry) -> Option<RegistryInfo> {
    let repos = fetch_all_repos(client, &registry.catalog_base).await?;

    let mut repositories = Vec::new();
    for repo in &repos {
        let tags = fetch_tags(client, &registry.catalog_base, repo).await;
        let tag_count = tags.len();
        repositories.push(RepoInfo {
            name: repo.clone(),
            tags,
        });
        if tag_count == 0 {
            continue;
        }
    }

    let images: usize = repositories.iter().map(|r| r.tags.len()).sum();

    Some(RegistryInfo {
        url: registry.upstream_url.clone(),
        images,
        repositories,
    })
}

fn build_summary(registries: &BTreeMap<String, RegistryInfo>) -> BTreeMap<String, serde_json::Value> {
    let mut summary = BTreeMap::new();
    let mut total: usize = 0;
    for (name, info) in registries {
        summary.insert(name.clone(), serde_json::json!(info.images));
        total += info.images;
    }
    summary.insert("total".to_string(), serde_json::json!(total));
    summary
}

async fn full_handler(State(state): State<Arc<AppState>>) -> (StatusCode, Json<FullResponse>) {
    let mut registries = BTreeMap::new();

    for reg in &state.registries {
        if let Some(info) = query_registry(&state.client, reg).await {
            registries.insert(reg.name.clone(), info);
        }
    }

    let summary = build_summary(&registries);
    (StatusCode::OK, Json(FullResponse { registries, summary }))
}

async fn summary_handler(
    State(state): State<Arc<AppState>>,
) -> (StatusCode, Json<SummaryResponse>) {
    let mut registries = BTreeMap::new();

    for reg in &state.registries {
        if let Some(info) = query_registry(&state.client, reg).await {
            registries.insert(reg.name.clone(), info);
        }
    }

    let summary = build_summary(&registries);
    (StatusCode::OK, Json(SummaryResponse { summary }))
}

#[tokio::main]
async fn main() {
    let registries = parse_registries();
    let client = Client::builder()
        .timeout(Duration::from_secs(5))
        .build()
        .expect("failed to build HTTP client");

    let state = Arc::new(AppState {
        registries,
        client,
    });

    let app = Router::new()
        .route("/", get(full_handler))
        .route("/summary", get(summary_handler))
        .with_state(state);

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3000);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");
    eprintln!("listening on {}", addr);
    axum::serve(listener, app).await.expect("server error");
}
