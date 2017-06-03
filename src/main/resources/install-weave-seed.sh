    # launching seed weave node with
    # - encryption
    # - fixed set of seeds forming the quorum
    # - IP address allocation space split in half for automatic and manual allocation
    # see https://www.weave.works/docs/net/latest/operational-guide/uniform-fixed-cluster/
    weave launch --password __TOKEN__ --ipalloc-range 10.32.0.0/13 --ipalloc-default-subnet 10.32.0.0/12 __SEEDS__
    weave prime