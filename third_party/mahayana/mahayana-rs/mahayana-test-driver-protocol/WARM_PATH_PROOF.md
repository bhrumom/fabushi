# FCM-019 optimized leaf-lane proof

This evidence-only file exercises the modeled `mahayana-test-driver-protocol` leaf path after package-only rustfmt and a dedicated test-driver Cargo cache were introduced.

The first PR run establishes the cold dedicated-cache baseline. A second no-product-change commit in the same PR is used to measure the warm cache on the same PR cache scope. The PR is closed without merge after evidence is recorded.
