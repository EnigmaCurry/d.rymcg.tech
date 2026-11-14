## Migrate OpenBao's file storage to raft, in place in the /openbao/file
## volume. Piped into the openbao container by `make migrate-raft`. Needs
## OpenBao 2.6.x: 2.7 can't read the file backend.
set -e
cd /openbao/file
if [ -d raft ]; then
    echo "Already on raft storage; nothing to migrate."
    exit 0
fi
if [ ! -d core ]; then
    echo "ERROR: no file-backend data found in /openbao/file." >&2
    exit 1
fi
case "$(bao version)" in
    "OpenBao v2.6."*|"OpenBao v2.5."*|"OpenBao v2.4."*) ;;
    *) echo "ERROR: run this on OpenBao 2.6.x, not: $(bao version)" >&2; exit 1 ;;
esac
## Move the file-backend data aside, so raft can use /openbao/file:
if [ ! -d legacy-file ]; then
    mkdir legacy-file
    for f in * .[!.]*; do
        [ -e "$f" ] && [ "$f" != legacy-file ] && mv "$f" legacy-file/
    done
fi
cat > /tmp/migrate.hcl <<HCL
storage_source "file" {
  path = "/openbao/file/legacy-file"
}
storage_destination "raft" {
  path    = "/openbao/file"
  node_id = "openbao"
}
cluster_addr = "https://127.0.0.1:8201"
HCL
bao operator migrate -config /tmp/migrate.hcl
echo "Migrated to raft. The old data is kept in /openbao/file/legacy-file."
