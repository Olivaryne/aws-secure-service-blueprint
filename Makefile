.PHONY: fmt validate test check

fmt:
	terraform fmt -recursive

validate:
	terraform init -backend=false -input=false
	terraform validate

test:
	terraform test -no-color

check:
	terraform fmt -check -recursive
	terraform init -backend=false -input=false
	terraform validate
	terraform test -no-color
