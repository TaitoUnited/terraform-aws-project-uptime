/**
 * Copyright 2019 Taito United
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "aws_route53_health_check" "uptimez" {
  count = length(var.uptime_targets)

  fqdn              = var.domain
  port              = 443
  type              = "HTTPS"
  resource_path     = var.uptime_paths[count.index]
  failure_threshold = "3"
  request_interval  = "10"
  measure_latency   = true
  regions           = [
    "sa-east-1", "us-west-1", "us-west-2", "ap-northeast-1",
    "ap-southeast-1", "eu-west-1", "us-east-1", "ap-southeast-2"
  ]

  # TODO: uptime_timeouts

  tags = {
    Name = "${var.project}-${var.env}"
    Domain = var.domain
    Target = var.uptime_targets[count.index]
    Path = var.uptime_paths[count.index]
  }
}

resource "aws_route53_health_check" "uptimez_aggregate" {
  type                   = "CALCULATED"
  child_health_threshold = 1
  child_healthchecks     = [
    for uptimez in aws_route53_health_check.uptimez:
    uptimez.id
  ]

  tags = {
    Name = "${var.project}-${var.env}"
    Domain = var.domain
  }
}

resource "aws_cloudwatch_metric_alarm" "uptimez_failed" {
  alarm_name          = "${var.project}-${var.env} uptime check"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  unit                = "None"
  dimensions = {
    HealthCheckId = "${aws_route53_health_check.uptimez_aggregate.id}"
  }
  alarm_description   = "This metric monitors whether the service endpoint is down or not."
  alarm_actions       = [ var.uptime_channels[0] ]
  insufficient_data_actions = [ var.uptime_channels[0] ]
  treat_missing_data  = "breaching"
}
