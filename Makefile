.PHONY: check bootstrap uboot kernel deploy patches

check:
	bash scripts/check_host.sh

bootstrap:
	bash scripts/bootstrap_sources.sh

uboot:
	bash scripts/build_uboot.sh

kernel:
	bash scripts/build_kernel.sh

deploy:
	bash scripts/deploy_tftp.sh dev

patches:
	bash scripts/export_patches.sh
