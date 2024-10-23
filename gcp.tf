resource "google_compute_network" "gcp-vpc" {
  name                    = "gcp-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "public_subnet" {
  name                     = "public-subnet"
  ip_cidr_range            = var.gcp_cidr[0]
  region                   = var.gcp_region
  network                  = google_compute_network.gcp-vpc.name
  private_ip_google_access = true
}
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "private-subnet"
  ip_cidr_range            = var.gcp_cidr[1]
  region                   = var.gcp_region
  network                  = google_compute_network.gcp-vpc.name
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-icmp" {
  name          = "allow-icmp"
  network       = google_compute_network.gcp-vpc.id
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"

  }
}
resource "google_compute_firewall" "allow-ssh" {
  name          = "allow-ssh"
  network       = google_compute_network.gcp-vpc.id
  #source_ranges = ["35.235.240.0/20","${format(jsondecode(data.http.ipinfo.body).ip)}/32"]
  source_ranges = ["35.235.240.0/20","${chomp(data.http.icanhazip.response_body)}/32"]
  allow {
    protocol = "tcp"
    ports    = [22]
  }
}

resource "google_compute_router" "gcp-router" {
  name    = "gcp-router"
  region  = var.gcp_region
  network = google_compute_network.gcp-vpc.id

  bgp {
    asn               = 65273
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_nat" "gcp-nat" {
  name                               = "gcp-nat-router"
  router                             = google_compute_router.gcp-router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

}

resource "google_compute_ha_vpn_gateway" "gcp-gateway" {
  name       = "aws-vpn"
  region     = var.gcp_region
  network    = google_compute_network.gcp-vpc.name
  stack_type = "IPV4_IPV6"
}

resource "google_compute_external_vpn_gateway" "aws-gateway" {
  name            = "aws-gateway"
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  description     = "VPN gateway on AWS side"
  interface {
    id         = 0
    ip_address = aws_vpn_connection.vpn1.tunnel1_address
  }
  interface {
    id         = 1
    ip_address = aws_vpn_connection.vpn1.tunnel2_address
  }
  interface {
    id         = 2
    ip_address = aws_vpn_connection.vpn2.tunnel1_address
  }
  interface {
    id         = 3
    ip_address = aws_vpn_connection.vpn2.tunnel2_address
  }
}

resource "google_compute_vpn_tunnel" "vpn1" {
  name                            = "vpn-tunnel-1"
  peer_external_gateway           = google_compute_external_vpn_gateway.aws-gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = aws_vpn_connection.vpn1.tunnel1_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 0
}

resource "google_compute_router_peer" "peer1" {
  name            = "peer-1"
  router          = google_compute_router.gcp-router.name
  region          = google_compute_router.gcp-router.region
  peer_ip_address = aws_vpn_connection.vpn1.tunnel1_vgw_inside_address
  peer_asn        = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  interface       = google_compute_router_interface.int1.name
}

resource "google_compute_router_interface" "int1" {
  name       = "interface-1"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "${aws_vpn_connection.vpn1.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn1.name
}

resource "google_compute_vpn_tunnel" "vpn2" {
  name                            = "vpn-tunnel-2"
  peer_external_gateway           = google_compute_external_vpn_gateway.aws-gateway.id
  peer_external_gateway_interface = 1
  shared_secret                   = aws_vpn_connection.vpn1.tunnel2_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 0
}

resource "google_compute_router_peer" "peer2" {
  name            = "peer-2"
  router          = google_compute_router.gcp-router.name
  region          = google_compute_router.gcp-router.region
  peer_ip_address = aws_vpn_connection.vpn1.tunnel2_vgw_inside_address
  peer_asn        = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  interface       = google_compute_router_interface.int2.name
}

resource "google_compute_router_interface" "int2" {
  name       = "interface-2"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "${aws_vpn_connection.vpn1.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn2.name
}

resource "google_compute_vpn_tunnel" "vpn3" {
  name                            = "vpn-tunnel-3"
  peer_external_gateway           = google_compute_external_vpn_gateway.aws-gateway.id
  peer_external_gateway_interface = 2
  shared_secret                   = aws_vpn_connection.vpn2.tunnel1_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 1
}

resource "google_compute_router_peer" "peer3" {
  name            = "peer-3"
  router          = google_compute_router.gcp-router.name
  region          = google_compute_router.gcp-router.region
  peer_ip_address = aws_vpn_connection.vpn2.tunnel1_vgw_inside_address
  peer_asn        = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  interface       = google_compute_router_interface.int3.name
}

resource "google_compute_router_interface" "int3" {
  name       = "interface-3"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "${aws_vpn_connection.vpn2.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn3.name
}

resource "google_compute_vpn_tunnel" "vpn4" {
  name                            = "vpn-tunnel-4"
  peer_external_gateway           = google_compute_external_vpn_gateway.aws-gateway.id
  peer_external_gateway_interface = 3
  shared_secret                   = aws_vpn_connection.vpn2.tunnel2_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-gateway.self_link
  router                          = google_compute_router.gcp-router.name
  vpn_gateway_interface           = 1
}

resource "google_compute_router_peer" "peer4" {
  name            = "peer-4"
  router          = google_compute_router.gcp-router.name
  region          = google_compute_router.gcp-router.region
  peer_ip_address = aws_vpn_connection.vpn2.tunnel2_vgw_inside_address
  peer_asn        = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  interface       = google_compute_router_interface.int4.name
}

resource "google_compute_router_interface" "int4" {
  name       = "interface-4"
  router     = google_compute_router.gcp-router.name
  region     = google_compute_router.gcp-router.region
  ip_range   = "${aws_vpn_connection.vpn2.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpn4.name
}