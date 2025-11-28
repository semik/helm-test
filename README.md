# Demo repo for CZERTAINLY Helm Chart deployment

This repository contains sereral branches:
- `develop`: Development environment configuration
- `acceptance`: Acceptance environment configuration
- `prod`: Production environment configuration

It can be extended with 'feature' branches for developing new branches, however those are not part of this demo.

To change CZERTAINLY version, please edit `Chart.yaml` file in this repository with proper version and commit the change.

To change specific parameters for each environment, please edit corresponding `values-<env>.yaml` files. Shared parameters can be found in `values-shared.yaml` file.