# Your AWS Access and Secret keys for programmatic (CLI-initiated) operations.
# See more: https://docs.aws.amazon.com/general/latest/gr/managing-aws-access-keys.html
aws_access_key = "YOUR_AWS_ACCESS_KEY_FOR_CLI_OPERATIONS"
aws_secret_key = "YOUR_AWS_SECRET_KEY_FOR_CLI_OPERATIONS"

# The following variables define where to launch EC2 instances
# Change it, if you would like to use antoher region.
# Note: change of a region likely requires another AMI image reference (see below)
aws_region = "ap-southeast-2"
aws_region_zone_1 = "ap-southeast-2a"
aws_region_zone_2 = "ap-southeast-2b"
aws_region_zone_3 = "ap-southeast-2c"

# The following varaibles define what instance type and AMI image to use
# Change it, if you would like to use different image or instance type.
# Ubuntu AMI images can be found here http://cloud-images.ubuntu.com/locator/ec2/
aws_ami_image = "ami-a80114cb"
aws_instance_type = "m3.medium"

# The following varaible is referred in the definition of security groups
# It should be the same as your AWS private network CIDR
aws_cidr = "172.31.0.0/16" # this is default for AWS accounts

# The following variable is used for labeling purpose.
# Change it if you would like to tag you EC2 instances differently.
aws_service_name = "cluterlite.demo"

# The following variable is exported public key of openssl certificate.
# The corresponding private key is saved in sshkey.pem file and is used
# during remote access to the machines via SSH for atuomated provisioning.
aws_key_pair_public = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0LpLi4ADU+z6DJzVm02nAlgBZFOoBldCXNKMgWjISx/sX6PSwCVoi2NTug//EqREL1J/5nsUkWRLX3H6HCeIkYOZwbfoW+PBsniAw+iyZE1YF8+bOwiKVNxmb7+A4/j2EL7Rb9fK6qvOl/mxcAQ94lRpNiBWYrt7CuaQY/jd7mnXRAf0Fc0Kr87DapMeyusXoI5w9GNC4UOJgjEkluYn5TQCqGJYD/R1kViQkQXwWYNkGqkYWQ5h0S7xWcC+8YOvu0zdpWIZ+39bbUHIFpByBM8Z10NzGL1i63JpBMoU34d1NleBBPXQLLbcBi4/wIkdJhEYztdsv/gggH7IwJwzCQIDAQAB"
