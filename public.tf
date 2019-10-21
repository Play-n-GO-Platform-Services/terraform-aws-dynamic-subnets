module "public_label" {
  source     = "git::https://github.com/Play-n-GO-Platform-Services/terraform-null-label.git?ref=playngoplatformv1.0"
  context    = module.label.context
  attributes = compact(concat(module.label.attributes, ["public"]))
  enabled    = var.enabled
  tags = merge(
    module.label.tags,
    map(var.subnet_type_tag_key, format(var.subnet_type_tag_value_format, "public"))
  )
}

locals {
  public_subnet_count = var.max_subnet_count == 0 ? length(element(concat(data.aws_availability_zones.available.*.names,list("")),0)) : var.max_subnet_count
}

resource "aws_subnet" "public" {
  count             = var.enabled ? length(var.availability_zones) : 0
  vpc_id            = element(data.aws_vpc.default.*.id,0)
  availability_zone = element(var.availability_zones, count.index)

  cidr_block = cidrsubnet(
    signum(length(var.cidr_block)) == 1 ? var.cidr_block : element(data.aws_vpc.default.*.cidr_block,0),
    ceil(log(local.public_subnet_count * 2, 2)),
    local.public_subnet_count + count.index
  )

  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    module.public_label.tags,
    {
      "Name" = format(
        "%s%s%s",
        module.public_label.id,
        var.delimiter,
        replace(
          element(var.availability_zones, count.index),
          "-",
          var.delimiter
        )
      )
    }
  )

  lifecycle {
    # Ignore tags added by kops or kubernetes
    ignore_changes = ["tags.kubernetes", "tags.SubnetType"]
  }
}

resource "aws_route_table" "public" {
  count  = var.enabled == false && signum(length(var.vpc_default_route_table_id)) == 1 ? 0 : 1
  vpc_id = element(concat(data.aws_vpc.default.*.id,list("")),0)
  tags = module.public_label.tags
}

resource "aws_route" "public" {
  count                  = var.enabled == false && signum(length(var.vpc_default_route_table_id)) == 1 ? 0 : 1
  route_table_id         = join("", aws_route_table.public.*.id)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.igw_id
}

resource "aws_route_table_association" "public" {
  count          = var.enabled == false && signum(length(var.vpc_default_route_table_id)) == 1 ? 0 : length(var.availability_zones)
  subnet_id      = element(concat(aws_subnet.public.*.id,list("")), count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "public_default" {
  count          = var.enabled == true && signum(length(var.vpc_default_route_table_id)) == 1 ? length(var.availability_zones) : 0
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = var.vpc_default_route_table_id
}

resource "aws_network_acl" "public" {
  count      = var.enabled == true && signum(length(var.public_network_acl_id)) == 0 ? 1 : 0
  vpc_id     = var.vpc_id
  subnet_ids = aws_subnet.public.*.id

  egress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }

  ingress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }

  tags = module.public_label.tags
}

