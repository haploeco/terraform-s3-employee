/**
 * A terraform module that creates a tagged S3 bucket with federated assumed role access.

 *Note that the `role_users` must be valid roles that exist in the same account that the script is run in.
 */

resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.bucket_name}"
  force_destroy = "true"

  versioning {
    enabled = "${var.versioning}"
  }

  tags {
    team          = "${var.tag_team}"
    application   = "${var.tag_application}"
    environment   = "${var.tag_environment}"
    contact-email = "${var.tag_contact-email}"
    customer      = "${var.tag_customer}"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = "${aws_s3_bucket.bucket.id}"
  policy = "${data.template_file.policy.rendered}"
}

data "aws_caller_identity" "current" {}

//render dynamic list of users
data "template_file" "principal" {
  count    = "${length(var.role_users)}"
  template = "arn:aws:sts::$${account}:assumed-role/$${user}"

  vars {
    account = "${data.aws_caller_identity.current.account_id}"
    user    = "${var.role_users[count.index]}"
  }
}

//render policy including dynamic principals
data "template_file" "policy" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [    
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": [ "s3:*" ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ],
      "Condition": {
        "StringNotLike": {
          "aws:arn": $${principals}
        }
      }      
    }    
  ]
}
EOF

  vars {
    account    = "${data.aws_caller_identity.current.account_id}"
    principals = "${jsonencode(data.template_file.principal.*.rendered)}"
  }
}
