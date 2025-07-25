resource "google_storage_bucket" "website" {
  name     = var.bucket_name
  location = var.bucket_location
}

resource "google_storage_object_access_control" "public_rule" {
  object = var.object_name
  bucket = var.bucket_name
  role   = var.object_role
  entity = var.object_entity
}

resource "google_storage_bucket_object" "static_website" {
  name   = var.object_name
  source = var.object_source
  bucket = var.bucket_name
}

resource "google_compute_global_address" "website_ip" {
  name = var.global_address_name
}

data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone_name
}

resource "google_dns_record_set" "website_dns" {
  name         = "website.${data.google_dns_managed_zone.dns_zone.dns_name}"
  type         = var.dns_record_type
  ttl          = var.dns_record_ttl
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  rrdatas      = [google_compute_global_address.website_ip.address]
}

resource "google_compute_backend_bucket" "website_backend" {
  name        = var.backend_bucket_name
  bucket_name = var.bucket_name
  description = var.backend_bucket_description
  enable_cdn  = var.backend_bucket_enable_cdn
}

resource "google_compute_url_map" "website" {
  name            = var.url_map_name
  default_service = google_compute_backend_bucket.website_backend.self_link
  host_rule {
    hosts        = var.url_map_hosts
    path_matcher = var.url_map_path_matcher
  }
  path_matcher {
    name            = var.url_map_path_matcher
    default_service = google_compute_backend_bucket.website_backend.self_link
  }
}

resource "google_compute_target_http_proxy" "website_proxy" {
  name    = var.target_http_proxy_name
  url_map = google_compute_url_map.website.self_link
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = var.forwarding_rule_name
  load_balancing_scheme = var.forwarding_rule_scheme
  ip_address            = google_compute_global_address.website_ip.address
  ip_protocol           = var.forwarding_rule_protocol
  port_range            = var.forwarding_rule_port
  target                = google_compute_target_http_proxy.website_proxy.self_link
}
