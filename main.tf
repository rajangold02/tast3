provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "${var.vpccidrblock}"
  instance_tenancy     = "${var.instanceTenancy}"
  enable_dns_support   = "${var.dnssupport}"
  enable_dns_hostnames = "${var.dnshostnames}"

  tags {
    Name = "My custom VPC"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "my_public_subnet" {
  vpc_id                  = "${aws_vpc.my_vpc.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.my_vpc.cidr_block, 8,count.index + 1)}"
  map_public_ip_on_launch = "${var.mappublicip}"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "My Public Subnet"
  }
}

resource "aws_subnet" "my_private_subnet" {
  vpc_id            = "${aws_vpc.my_vpc.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.my_vpc.cidr_block, 8,count.index + 2)}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "My Private Subnet"
  }
}

resource "aws_internet_gateway" "my_vpc_gw" {
  vpc_id = "${aws_vpc.my_vpc.id}"

  tags {
    Name = "My VPC Internet Gateway"
  }
}

resource "aws_route_table" "my_public_route_table" {
  vpc_id = "${aws_vpc.my_vpc.id}"

  tags {
    Name = "My public Route Table"
  }
}

resource "aws_route_table" "my_private_route_table" {
  vpc_id = "${aws_vpc.my_vpc.id}"

  tags {
    Name = "My private Route Table"
  }
}

resource "aws_route" "my_vpc_internet_access" {
  route_table_id         = "${aws_route_table.my_public_route_table.id}"
  destination_cidr_block = "${var.destinationcidrblock}"
  gateway_id             = "${aws_internet_gateway.my_vpc_gw.id}"
}

resource "aws_route_table_association" "my_vpc_association" {
  subnet_id      = "${aws_subnet.my_public_subnet.id}"
  route_table_id = "${aws_route_table.my_public_route_table.id}"
}

resource "aws_route_table_association" "my_vpc_private_association" {
  subnet_id      = "${aws_subnet.my_private_subnet.id}"
  route_table_id = "${aws_route_table.my_private_route_table.id}"
}

resource "aws_security_group" "elb" {
  name        = "elb_all"
  description = "Allow all http and ssh traffic"
  vpc_id      = "${aws_vpc.my_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance" {
  description = "Allow all ssh and http traffic"
  vpc_id      = "${aws_vpc.my_vpc.id}"
  name        = "tf-ecs-instsg"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create ecs
resource "aws_ecs_cluster" "main" {
  name = "nodejs_ecs_cluster"
}

data "template_file" "task_definition" {
  template = "${file("./task-definition.json")}"

  vars {
    image_url        = "rajangold02/node:latest"
    container_name   = "node"
    log_group_region = "${var.region}"
    log_group_name   = "${aws_cloudwatch_log_group.app.name}"
  }
}

resource "aws_ecs_task_definition" "node" {
  family                = "service"
  container_definitions = "${data.template_file.task_definition.rendered}"
}

resource "aws_ecs_service" "ecs" {
  name            = "ecs_nodejs"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.node.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs_service.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb.id}"
    container_name   = "node"
    container_port   = "80"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.front_end",
  ]
}

## Creating AutoScaling Group

resource "aws_autoscaling_group" "ag" {
  launch_configuration = "${aws_launch_configuration.launch_config.id}"
  name                 = "Auto_scaling_group"
  vpc_zone_identifier  = ["${aws_subnet.my_public_subnet.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"

  tags = {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "template_file" "cloud_config" {
  template = "${file("config.yml")}"

  vars {
    aws_region         = "${var.region}"
    ecs_cluster_name   = "${aws_ecs_cluster.main.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
  }
}

data "aws_ami" "stable_coreos" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS Container Linux stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"]
}


## Creating Launch Configuration
resource "aws_launch_configuration" "launch_config" {
  image_id                    = "${data.aws_ami.stable_coreos.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  security_groups             = ["${aws_security_group.instance.id}"]
  key_name                    = "${var.keypair_name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_alb_target_group" "alb" {
  name     = "nodej-alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.my_vpc.id}"
}

resource "aws_alb" "main" {
  name            = "alb-ecs"
  subnets         = ["${aws_subnet.my_public_subnet.*.id}", "${aws_subnet.my_private_subnet.*.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb.id}"
    type             = "forward"
  }
}

# Identity and Access Management
resource "aws_iam_role" "ecs_service" {
  name = "${var.ecs_service_role_name}"

  assume_role_policy = "${file("assume-role-policy.json")}"
}

resource "aws_iam_role_policy" "ecs_service" {
  name   = "nodejs_ecs_policy"
  role   = "${aws_iam_role.ecs_service.name}"
  policy = "${file("nodejs_ecs_policy.json")}"
}

resource "aws_iam_instance_profile" "app" {
  name = "nj-ecs-instprofile"
  role = "${aws_iam_role.app_instance.name}"
}

resource "aws_iam_role" "app_instance" {
  name = "nj-ecs-instance-role"

  assume_role_policy = "${file("ec2-role.json")}"
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.app.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "NjEcsInstanceRole"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

#CloudWatch
resource "aws_cloudwatch_log_group" "ecs" {
  name = "ecs-group/ecs"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "ecs-group/app"
}
