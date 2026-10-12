import os

import boto3
from botocore.exceptions import ClientError


def lambda_handler(event, context):
    """Remove public SSH/RDP rules created by AuthorizeSecurityGroupIngress."""
    ec2 = boto3.client("ec2")
    sns = boto3.client("sns")

    request = event.get("detail", {}).get("requestParameters", {})
    sg_id = request.get("groupId")
    permissions = request.get("ipPermissions", {}).get("items", [])
    if not sg_id:
        print("Remediation ignored: security group ID missing")
        return {"status": "ignored", "reason": "security group id missing"}

    revoked = []
    for permission in permissions:
        from_port = permission.get("fromPort")
        to_port = permission.get("toPort", from_port)
        if from_port not in (22, 3389) or to_port != from_port:
            continue

        public_ranges = [
            {"CidrIp": item["cidrIp"]}
            for item in permission.get("ipRanges", {}).get("items", [])
            if item.get("cidrIp") == "0.0.0.0/0"
        ]
        if not public_ranges:
            continue

        try:
            ec2.revoke_security_group_ingress(
                GroupId=sg_id,
                IpPermissions=[
                    {
                        "IpProtocol": permission.get("ipProtocol", "tcp"),
                        "FromPort": from_port,
                        "ToPort": to_port,
                        "IpRanges": public_ranges,
                    }
                ],
            )
        except ClientError as error:
            if error.response["Error"]["Code"] == "InvalidPermission.NotFound":
                print(f"Remediation already complete: {sg_id}:{from_port}")
                continue
            raise
        revoked.append(f"{sg_id}:{from_port}")

    if revoked:
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Subject="DEPI security auto-remediation",
            Message="Removed public SSH/RDP rule(s): " + ", ".join(revoked),
        )

    status = "remediated" if revoked else "ignored"
    print(f"Remediation {status}: {revoked}")
    return {"status": status, "rules": revoked}
