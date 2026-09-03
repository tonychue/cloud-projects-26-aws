# AWS IAM AssumeRole Setup and Temporary Credentials

## 1. Objective

Configure AWS CLI so that an IAM user, `Bob`, assumes `example-role` and stores the resulting temporary credentials in a separate AWS CLI profile.

The final architecture is:

```text
Bob
 │
 │ example_profile
 │
 │ sts:AssumeRole
 ▼
example-role
 │
 │ Trust Policy:
 │ arn:aws:iam::545910165528:root
 │
 ▼
Temporary Credentials
 │
 ▼
assumed_role
```

### AWS configuration

| Item            | Value                                         |
| --------------- | --------------------------------------------- |
| AWS Account     | `545910165528`                                |
| IAM User        | `Bob`                                         |
| Source Profile  | `example_profile`                             |
| IAM Role        | `example-role`                                |
| Role ARN        | `arn:aws:iam::545910165528:role/example-role` |
| Target Profile  | `assumed_role`                                |
| Default Session | `3600` seconds / 1 hour                       |

---

# 2. Prerequisites

Verify AWS CLI:

```bash
aws --version
```

Verify `jq`:

```bash
jq --version
```

If `jq` is not installed on macOS:

```bash
brew install jq
```

---

# 3. Configure Bob's Source Profile

Configure Bob's AWS credentials under `example_profile`:

```bash
aws configure --profile example_profile
```

Enter Bob's credentials:

```text
AWS Access Key ID:
AWS Secret Access Key:
Default region name:
Default output format:
```

The source profile must contain Bob's credentials.

---

# 4. Verify the Source Profile

Run:

```bash
aws sts get-caller-identity --profile example_profile
```

Expected:

```json
{
    "Account": "545910165528",
    "Arn": "arn:aws:iam::545910165528:user/Bob"
}
```

The important value is:

```text
arn:aws:iam::545910165528:user/Bob
```

If this returns `tfuser`, the wrong credentials are configured in `example_profile`.

---

# 5. IAM Policy for Bob

Bob must be allowed to call `sts:AssumeRole`.

Create:

```text
bob-assume-role.json
```

with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeExampleRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::545910165528:role/example-role"
    }
  ]
}
```

Attach it to Bob:

```bash
aws iam put-user-policy \
  --user-name Bob \
  --policy-name AllowAssumeExampleRole \
  --policy-document file://bob-assume-role.json
```

Verify:

```bash
aws iam list-user-policies \
  --user-name Bob \
  --profile example_profile
```

---

# 6. Configure the Role Trust Policy

`example-role` trusts the AWS account root:

```text
arn:aws:iam::545910165528:root
```

Create:

```text
trust-policy.json
```

with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TrustAccountRoot",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::545910165528:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Update the role:

```bash
aws iam update-assume-role-policy \
  --role-name example-role \
  --policy-document file://trust-policy.json \
  --profile example_profile
```

---

# 7. Verify the Trust Policy

Run:

```bash
aws iam get-role \
  --role-name example-role \
  --profile example_profile \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

The trust policy should contain:

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::545910165528:root"
  }
}
```

---

# 8. Understand the Two-Sided Permission Model

AWS role assumption requires both sides to permit the operation.

### Bob's identity policy

Bob must have:

```text
sts:AssumeRole
```

against:

```text
arn:aws:iam::545910165528:role/example-role
```

### Role trust policy

The role must trust:

```text
arn:aws:iam::545910165528:root
```

Therefore:

```text
Bob
 │
 │ Identity Policy
 │ Allow sts:AssumeRole
 ▼
example-role
 │
 │ Trust Policy
 │ Principal = Account Root
 ▼
545910165528
```

The root principal in the trust policy delegates trust to the account. It does not mean that only the AWS account root user can assume the role.

---

# 9. Test AssumeRole Manually

Before using the script, test:

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::545910165528:role/example-role" \
  --role-session-name AWSCLI-Session \
  --profile example_profile
```

If successful, AWS returns temporary credentials:

```json
{
  "Credentials": {
    "AccessKeyId": "...",
    "SecretAccessKey": "...",
    "SessionToken": "...",
    "Expiration": "..."
  },
  "AssumedRoleUser": {
    "Arn": "arn:aws:sts::545910165528:assumed-role/example-role/AWSCLI-Session"
  }
}
```

---

# 10. AssumeRole Script

Create:

```bash
nano assume-role.sh
```

Make it executable:

```bash
chmod +x assume-role.sh
```

The script accepts:

```text
./assume-role.sh <role-arn> <source-profile> <target-profile> [duration-seconds]
```

Example:

```bash
./assume-role.sh \
  "arn:aws:iam::545910165528:role/example-role" \
  example_profile \
  assumed_role \
  3600
```

The source and target profiles are intentionally separate.

```text
example_profile
      │
      │ Bob credentials
      ▼
   AssumeRole
      │
      ▼
example-role
      │
      │ temporary credentials
      ▼
assumed_role
```

---

# 11. Verify the Assumed Role

After running the script:

```bash
aws sts get-caller-identity --profile assumed_role
```

Expected:

```json
{
    "Account": "545910165528",
    "Arn": "arn:aws:sts::545910165528:assumed-role/example-role/AWSCLI-Session"
}
```

This confirms that `assumed_role` is using the temporary credentials for `example-role`.

---

# 12. Use the Assumed Role

For example:

```bash
aws s3 ls --profile assumed_role
```

Or:

```bash
aws sts get-caller-identity --profile assumed_role
```

For Terraform:

```bash
export AWS_PROFILE=assumed_role
```

Then:

```bash
terraform plan
```

or:

```bash
terraform apply
```

---

# 13. Session Duration

The script accepts duration in seconds.

Examples:

```text
900     = 15 minutes
1800    = 30 minutes
3600    = 1 hour
7200    = 2 hours
14400   = 4 hours
43200   = 12 hours
```

Check the role's maximum:

```bash
aws iam get-role \
  --role-name example-role \
  --profile example_profile \
  --query 'Role.MaxSessionDuration' \
  --output text
```

The requested duration cannot exceed the role's configured maximum.

---

# 14. AWS Credential Profiles

The intended configuration is:

```text
~/.aws/credentials
```

```ini
[example_profile]
aws_access_key_id = <BOB_ACCESS_KEY>
aws_secret_access_key = <BOB_SECRET_KEY>

[assumed_role]
aws_access_key_id = <TEMP_ACCESS_KEY>
aws_secret_access_key = <TEMP_SECRET_KEY>
aws_session_token = <TEMP_SESSION_TOKEN>
```

### Important

Do not overwrite `example_profile` with the temporary credentials.

`example_profile` is the source identity used to obtain new sessions.

`assumed_role` contains the temporary credentials.

---

# 15. Complete Workflow

### Step 1 — Verify Bob

```bash
aws sts get-caller-identity --profile example_profile
```

Expected:

```text
arn:aws:iam::545910165528:user/Bob
```

### Step 2 — Assume the role

```bash
./assume-role.sh \
  "arn:aws:iam::545910165528:role/example-role" \
  example_profile \
  assumed_role \
  3600
```

### Step 3 — Verify the role

```bash
aws sts get-caller-identity --profile assumed_role
```

Expected:

```text
arn:aws:sts::545910165528:assumed-role/example-role/AWSCLI-Session
```

### Step 4 — Use AWS

```bash
aws s3 ls --profile assumed_role
```

---

# 16. Troubleshooting

## tfuser appears instead of Bob

Run:

```bash
aws sts get-caller-identity --profile example_profile
```

If you see:

```text
arn:aws:iam::545910165528:user/tfuser
```

then `example_profile` is using the wrong credentials.

Reconfigure:

```bash
aws configure --profile example_profile
```

---

## Bob is denied AssumeRole

Check Bob's policies:

```bash
aws iam list-user-policies \
  --user-name Bob \
  --profile example_profile
```

Bob needs:

```text
sts:AssumeRole
```

on:

```text
arn:aws:iam::545910165528:role/example-role
```

---

## Trust relationship problem

Check:

```bash
aws iam get-role \
  --role-name example-role \
  --profile example_profile \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

The role should trust:

```text
arn:aws:iam::545910165528:root
```

---

# 17. Security Notes

Temporary credentials should be treated as secrets.

Do not commit:

```text
~/.aws/credentials
```

or files containing access keys into Git.

Add to `.gitignore` where appropriate:

```gitignore
.aws/
*.env
```

Never paste the following into source control or public repositories:

```text
AWS Access Key ID
AWS Secret Access Key
AWS Session Token
```

The `assumed_role` credentials expire automatically according to the STS session duration.

When they expire, run the AssumeRole script again to obtain a new session.

---

# 18. Final Architecture

```text
                     AWS Account
                    545910165528
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
       IAM User: Bob             IAM Role:
                                  example-role
             │                         │
             │                         │
             │ sts:AssumeRole          │
             └────────────────────────►│
                                       │
                         Trusts account root:
                         arn:aws:iam::545910165528:root
                                       │
                                       ▼
                              Temporary Credentials
                                       │
                                       ▼
                                assumed_role
                                   profile
                                       │
                                       ▼
                              AWS CLI / Terraform
```


https://repost.aws/knowledge-center/iam-assume-role-cli
