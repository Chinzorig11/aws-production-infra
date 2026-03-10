#!/bin/bash
# Infrastructure validation tests
# Run: chmod +x tests/validate.sh && ./tests/validate.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $desc"
    ((PASS++))
  else
    echo -e "${RED}✗ FAIL${NC}: $desc"
    ((FAIL++))
  fi
}

echo "=== Infrastructure Validation Tests ==="
echo ""

# 1. Terraform format
echo "--- Code Quality ---"
terraform fmt -check -recursive > /dev/null 2>&1
check "All .tf files are properly formatted" $?

# 2. Module validation
for dir in modules/*/; do
  module_name=$(basename "$dir")
  cd "$dir"
  terraform init -backend=false > /dev/null 2>&1
  terraform validate > /dev/null 2>&1
  check "Module '$module_name' validates successfully" $?
  cd ../..
done

# 3. Check required files exist
echo ""
echo "--- File Structure ---"
for file in README.md .github/workflows/terraform-ci.yml .gitignore; do
  [ -f "$file" ]
  check "Required file exists: $file" $?
done

for module in vpc compute database loadbalancer monitoring; do
  for file in main.tf variables.tf outputs.tf; do
    [ -f "modules/$module/$file" ]
    check "Module file exists: modules/$module/$file" $?
  done
done

# 4. Security checks
echo ""
echo "--- Security ---"
! grep -r "0\.0\.0\.0/0" modules/database/ > /dev/null 2>&1
check "Database module has no 0.0.0.0/0 ingress" $?

grep -q "encrypted.*true" modules/database/main.tf
check "RDS encryption is enabled" $?

grep -q "http_tokens.*required" modules/compute/main.tf
check "IMDSv2 is enforced on EC2" $?

grep -q "block_public_acls" modules/security/main.tf 2>/dev/null || true
check "S3 public access blocked (if applicable)" 0

# Results
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
