# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


terraform {
  required_version = "~> 1.9"

  required_providers {
    ipam = {
      source  = "appvia/ipam"
      version = "~> 0.1"
    }
  }
}
