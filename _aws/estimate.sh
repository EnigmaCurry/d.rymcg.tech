#!/bin/bash
## Usage: ./estimate.sh <instance_type> <root_vol_gb> <docker_vol_gb> <region> <instance_name> <root_domain>
set -eo pipefail

INSTANCE_TYPE="$1"
ROOT_VOL="$2"
DOCKER_VOL="$3"
REGION="$4"
INSTANCE_NAME="$5"
ROOT_DOMAIN="$6"

echo ""
echo "## Cost estimate for: ${INSTANCE_NAME}.${ROOT_DOMAIN}"
echo "## Instance: ${INSTANCE_TYPE} | Region: ${REGION}"
echo "## Storage: ${ROOT_VOL} GB root + ${DOCKER_VOL} GB docker (gp3)"
echo ""
echo "## Fetching pricing..."

EC2_JSON=$(aws pricing get-products \
    --service-code AmazonEC2 \
    --filters \
        "Type=TERM_MATCH,Field=instanceType,Value=${INSTANCE_TYPE}" \
        "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
        "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
        "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
        "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
        "Type=TERM_MATCH,Field=regionCode,Value=${REGION}" \
    --region us-east-1 \
    --output json)

EBS_PRICE=$(aws pricing get-products \
    --service-code AmazonEC2 \
    --filters \
        "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
        "Type=TERM_MATCH,Field=volumeApiName,Value=gp3" \
        "Type=TERM_MATCH,Field=regionCode,Value=${REGION}" \
    --region us-east-1 \
    --output json \
    | jq -r '[.PriceList[] | fromjson | .terms.OnDemand[].priceDimensions[] | .pricePerUnit.USD | tonumber] | first')

echo "${EC2_JSON}" | jq -r --argjson ebs "${EBS_PRICE}" --argjson root "${ROOT_VOL}" --argjson docker "${DOCKER_VOL}" '
def hr: . * 10000 | round / 10000 | tostring | "$" + .;
def mo: . * 100 | round / 100 | tostring | "$" + . + "/mo";
def usd: . * 100 | round / 100 | tostring | "$" + .;
def pad($n): . + (" " * ($n - length));
{
    onDemand: ([.PriceList[] | fromjson | .terms.OnDemand[].priceDimensions[] | select(.pricePerUnit.USD != "0.0000000000") | .pricePerUnit.USD | tonumber] | first),
    reserved: [.PriceList[] | fromjson | .terms.Reserved // {} | to_entries[] | .value | {
        term: .termAttributes.LeaseContractLength,
        option: .termAttributes.PurchaseOption,
        hourly: ([.priceDimensions[] | select(.unit == "Hrs") | .pricePerUnit.USD | tonumber] | first // 0),
        upfront: ([.priceDimensions[] | select(.unit == "Quantity") | .pricePerUnit.USD | tonumber] | first // 0)
    }] | unique_by(.term, .option),
    ebsPerGB: $ebs,
    rootGB: $root,
    dockerGB: $docker
} |
    .ebsPerGB as $ebs | .rootGB as $root | .dockerGB as $docker |
    (.onDemand * 730) as $odMonthly |
    ($ebs * ($root + $docker)) as $ebsMonthly |

    "EC2 Compute (On-Demand)",
    "  \(.onDemand | hr)/hr  (\($odMonthly | mo))",
    "",
    "Reserved Instance Pricing",
    "  Term    Option            Hourly       Upfront      Eff./mo",
    "  ------  ----------------  -----------  -----------  -----------",
    (.reserved | sort_by(.term, .option)[] |
        (if .term == "1yr" then 12 else 36 end) as $months |
        ((.hourly * 730) + (.upfront / $months)) as $effMonthly |
        "  \(.term | pad(6))  \(.option | pad(16))  \(.hourly | hr | pad(11))  \(.upfront | usd | pad(11))  \($effMonthly | mo)"
    ),
    "",
    "EBS Storage (gp3 @ \($ebs | hr)/GB-mo)",
    "  Root:   \($root) GB = \($ebs * $root | mo)",
    "  Docker: \($docker) GB = \($ebs * $docker | mo)",
    "  Total EBS: \($ebsMonthly | mo)",
    "",
    "Estimated Monthly Total (On-Demand + EBS): \(($odMonthly + $ebsMonthly) | mo)"
' | sed 's/^/## /'
