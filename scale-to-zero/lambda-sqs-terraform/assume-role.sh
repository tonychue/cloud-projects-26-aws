#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Usage:
#
# ./assume-role.sh <role-arn> <source-profile> <target-profile> <duration>
#
# Example:
#
# ./assume-role.sh \
#   "arn:aws:iam::545910165528:role/example-role" \
#   example_profile \
#   assumed_role \
#   3600
#
# Flow:
#
# example_profile (Bob)
#        |
#        | sts:AssumeRole
#        v
# example-role
#        |
#        | temporary credentials
#        v
# assumed_role
# ============================================================

ROLE_ARN="${1:-}"
SOURCE_PROFILE="${2:-}"
TARGET_PROFILE="${3:-}"
DURATION="${4:-3600}"

SESSION_NAME="AWSCLI-Session"

# ============================================================
# Validate arguments
# ============================================================

if [[ -z "$ROLE_ARN" || -z "$SOURCE_PROFILE" || -z "$TARGET_PROFILE" ]]; then
    echo
    echo "Usage:"
    echo "  $0 <role-arn> <source-profile> <target-profile> [duration-seconds]"
    echo
    echo "Example:"
    echo "  $0 arn:aws:iam::545910165528:role/example-role example_profile assumed_role 3600"
    echo
    exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    echo "Error: duration must be a number of seconds."
    exit 1
fi

if (( DURATION < 900 )); then
    echo "Error: AWS requires a minimum session duration of 900 seconds."
    exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
    echo "Error: AWS CLI is not installed."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required."
    echo "Install with: brew install jq"
    exit 1
fi

# ============================================================
# Display configuration
# ============================================================

echo
echo "=========================================="
echo " AWS ASSUME ROLE"
echo "=========================================="
echo
echo "Role ARN:       $ROLE_ARN"
echo "Source profile: $SOURCE_PROFILE"
echo "Target profile: $TARGET_PROFILE"
echo "Duration:       $DURATION seconds"
echo

# ============================================================
# Verify source identity
# ============================================================

echo "Source identity:"
aws sts get-caller-identity \
    --profile "$SOURCE_PROFILE"

echo

# ============================================================
# Assume role
# ============================================================

echo "Assuming role..."

ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$SESSION_NAME" \
    --duration-seconds "$DURATION" \
    --profile "$SOURCE_PROFILE")

# ============================================================
# Extract temporary credentials
# ============================================================

ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
EXPIRATION=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.Expiration')

if [[ -z "$ACCESS_KEY_ID" || "$ACCESS_KEY_ID" == "null" ]]; then
    echo "Error: Failed to obtain temporary credentials."
    exit 1
fi

# ============================================================
# Save credentials to target profile
# ============================================================

echo
echo "Updating AWS profile: $TARGET_PROFILE"

aws configure set aws_access_key_id \
    "$ACCESS_KEY_ID" \
    --profile "$TARGET_PROFILE"

aws configure set aws_secret_access_key \
    "$SECRET_ACCESS_KEY" \
    --profile "$TARGET_PROFILE"

aws configure set aws_session_token \
    "$SESSION_TOKEN" \
    --profile "$TARGET_PROFILE"

# ============================================================
# Verify target profile
# ============================================================

echo
echo "Target identity:"
aws sts get-caller-identity \
    --profile "$TARGET_PROFILE"

# ============================================================
# Completion
# ============================================================

echo
echo "=========================================="
echo " ASSUME ROLE SUCCESSFUL"
echo "=========================================="
echo
echo "Source profile: $SOURCE_PROFILE"
echo "Target profile: $TARGET_PROFILE"
echo "Role:           $ROLE_ARN"
echo "Expires:        $EXPIRATION"
echo
echo "Use the assumed role with:"
echo
echo "  aws sts get-caller-identity --profile $TARGET_PROFILE"
echo
