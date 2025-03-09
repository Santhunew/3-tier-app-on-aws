#create VPC
resource "aws_vpc" "MyVPC" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true  
}

# internet gateway
resource "aws_internet_gateway" "MyIGW" {
  vpc_id = aws_vpc.MyVPC.id
}

#Route tabler for public and private subnet's
# Public Route Table
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.MyIGW.id
}

resource "aws_route_table_association" "public_assoc" {
  count = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table
resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.MyNatGateway.id
}

resource "aws_route_table_association" "private_assoc" {
  count = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}


# Nat Gateway
# Elastic IP for NAT Gateway
resource "aws_eip" "MyEIP" {
  domain = "vpc"
}


resource "aws_nat_gateway" "MyNatGateway" {
  subnet_id     = aws_subnet.public[0].id
  allocation_id = aws_eip.MyEIP.id
}


#create public subnet and private subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.MyVPC.id
  cidr_block = "10.0.${count.index + 1}.0/24"
  map_public_ip_on_launch = true
  count = 2
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.MyVPC.id
  cidr_block = "10.0.${count.index + 3}.0/24"
  count = 2
}

#network acl for public subnet and private subnet

resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.MyVPC.id
}

resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.MyVPC.id
}

#route table for public subnet and private subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.MyVPC.id
}       

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.MyVPC.id
}

#AWS Security Configuration (WAF, IAM)
resource "aws_waf_web_acl" "WAF" {
  name = "MyWAF"
  metric_name = "MyWAF"
  default_action {
    type = "ALLOW"
  }
}


#Deploy AWS CloudFront, S3, EC2, and RDS

# Create S3 Bucket
resource "aws_s3_bucket" "MyBucket" {
  bucket = "mybucketswaras"
}

# Configure S3 Bucket for Static Website Hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.MyBucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Enable Public Access (If Required)
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.MyBucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Define S3 Bucket Policy for Public Read Access
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.MyBucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.MyBucket.arn}/*"
      }
    ]
  })
}


# create cloudfront
resource "aws_cloudfront_distribution" "cdn" {
    origin {
        domain_name = aws_s3_bucket.MyBucket.bucket_regional_domain_name
        origin_id   = aws_s3_bucket.MyBucket.bucket_regional_domain_name
    }

    enabled = true

    default_cache_behavior {
        allowed_methods = ["GET", "HEAD"]
        cached_methods  = ["GET", "HEAD"]
        target_origin_id = aws_s3_bucket.MyBucket.bucket_regional_domain_name
        viewer_protocol_policy = "allow-all"
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

#create EC2 instance
resource "aws_instance" "MyEC2" {
  count = 3
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name = "Santhu"
  subnet_id = aws_subnet.public[count.index % 2].id
  vpc_security_group_ids = [aws_security_group.MySG.id]
}

#create RDS instance
resource "aws_db_instance" "MyRDS" {
    count = 3
    allocated_storage = 20
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t2.micro"
    identifier = "rds-instance-${count.index}"
}


#IAM role for EC2 and RDS
resource "aws_iam_role" "ec2_role" {
  name = "MyEC2Role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_role" "rds_role" {
  name = "MyRDSRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
   ]
  }
    EOF
}