# ====================================================================================
# Setup Project

export PROJECT_NAME ?= provider-upjet-alibabacloud
PROJECT_REPO ?= github.com/crossplane-contrib/$(PROJECT_NAME)

# Family provider configuration
export PROVIDER_NAME := alibabacloud
SUBPACKAGES ?= monolith

# Family provider package resolution
XPKG_SKIP_DEP_RESOLUTION := true

# Batch processing variables (OCI-aligned)
CONCURRENCY ?= 30
BUILD_ONLY ?= false
STORE_PACKAGES ?= ""

export TERRAFORM_VERSION ?= 1.5.7

# Do not allow a version of terraform greater than 1.5.x, due to versions 1.6+ being
# licensed under BSL, which is not permitted.
TERRAFORM_VERSION_VALID := $(shell [ "$(TERRAFORM_VERSION)" = "`printf "$(TERRAFORM_VERSION)\n1.6" | sort -V | head -n1`" ] && echo 1 || echo 0)

export TERRAFORM_PROVIDER_SOURCE ?= aliyun/alicloud
export TERRAFORM_PROVIDER_REPO ?= https://github.com/aliyun/terraform-provider-alicloud
export TERRAFORM_PROVIDER_VERSION ?= 1.256.0
export TERRAFORM_PROVIDER_DOWNLOAD_NAME ?= terraform-provider-alicloud
export TERRAFORM_PROVIDER_DOWNLOAD_URL_PREFIX ?= https://releases.hashicorp.com/$(TERRAFORM_PROVIDER_DOWNLOAD_NAME)/$(TERRAFORM_PROVIDER_VERSION)
export TERRAFORM_NATIVE_PROVIDER_BINARY ?= terraform-provider-alicloud_v1.256.0
export TERRAFORM_DOCS_PATH ?= website/docs/r


PLATFORMS ?= linux_amd64 linux_arm64

# -include will silently skip missing files, which allows us
# to load those files with a target in the Makefile. If only
# "include" was used, the make command would fail and refuse
# to run a target until the include commands succeeded.
-include build/makelib/common.mk

# ====================================================================================
# Setup Output

-include build/makelib/output.mk

# ====================================================================================
# Setup Go

# Set a sane default so that the nprocs calculation below is less noisy on the initial
# loading of this file
NPROCS ?= 1

# each of our test suites starts a kube-apiserver and running many test suites in
# parallel can lead to high CPU utilization. by default we reduce the parallelism
# to half the number of CPU cores.
GO_TEST_PARALLEL := $(shell echo $$(( $(NPROCS) / 2 )))

GO_REQUIRED_VERSION ?= 1.24.1
GOLANGCILINT_VERSION ?= 1.64.8
UPTEST_LOCAL_VERSION = v0.13.0
UPTEST_LOCAL_CHANNEL = stable
KUSTOMIZE_VERSION = v5.3.0
YQ_VERSION = v4.40.5
CROSSPLANE_VERSION = 1.19.0
CRDDIFF_VERSION = v0.12.1
GO_STATIC_PACKAGES ?= $(GO_PROJECT)/cmd/generator ${SUBPACKAGES:%=$(GO_PROJECT)/cmd/provider/%}
GO_LDFLAGS += -X $(GO_PROJECT)/internal/version.Version=$(VERSION)
GO_SUBDIRS += cmd internal apis
-include build/makelib/golang.mk

# ====================================================================================
# Setup Kubernetes tools

KIND_VERSION = v0.26.0
UP_VERSION = v0.38.0
UP_CHANNEL = stable
#UPTEST_VERSION = v0.13.1
UPTEST_VERSION = v1.1.2
-include build/makelib/k8s_tools.mk

# ====================================================================================
# Setup Images

REGISTRY_ORGS ?= xpkg.upbound.io/crossplane-contrib
IMAGES = $(PROJECT_NAME)
-include build/makelib/imagelight.mk

# ====================================================================================
# Setup XPKG

XPKG_REG_ORGS ?= xpkg.upbound.io/crossplane-contrib
# NOTE(hasheddan): skip promoting on xpkg.upbound.io as channel tags are
# inferred.
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/crossplane-contrib
XPKGS = $(PROJECT_NAME)
-include build/makelib/xpkg.mk

# ====================================================================================
# Fallthrough

# run `make help` to see the targets and options

# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

# NOTE(hasheddan): we force image building to happen prior to xpkg build so that
# we ensure image is present in daemon.
xpkg.build.provider-upjet-alibabacloud: do.build.images

# NOTE(hasheddan): we ensure up is installed prior to running platform-specific
# build steps in parallel to avoid encountering an installation race condition.
build.init: $(UP) check-terraform-version

# ====================================================================================
# Setup Terraform for fetching provider schema
TERRAFORM := $(TOOLS_HOST_DIR)/terraform-$(TERRAFORM_VERSION)
TERRAFORM_WORKDIR := $(WORK_DIR)/terraform
TERRAFORM_PROVIDER_SCHEMA := config/schema.json

check-terraform-version:
ifneq ($(TERRAFORM_VERSION_VALID),1)
	$(error invalid TERRAFORM_VERSION $(TERRAFORM_VERSION), must be less than 1.6.0 since that version introduced a not permitted BSL license))
endif

$(TERRAFORM): check-terraform-version
	@$(INFO) installing terraform $(HOSTOS)-$(HOSTARCH)
	@mkdir -p $(TOOLS_HOST_DIR)/tmp-terraform
	@curl -fsSL https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(SAFEHOST_PLATFORM).zip -o $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip
	@unzip $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip -d $(TOOLS_HOST_DIR)/tmp-terraform
	@mv $(TOOLS_HOST_DIR)/tmp-terraform/terraform $(TERRAFORM)
	@rm -fr $(TOOLS_HOST_DIR)/tmp-terraform
	@$(OK) installing terraform $(HOSTOS)-$(HOSTARCH)

$(TERRAFORM_PROVIDER_SCHEMA): $(TERRAFORM)
	@$(INFO) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)
	@mkdir -p $(TERRAFORM_WORKDIR)
	@echo '{"terraform":[{"required_providers":[{"provider":{"source":"'"$(TERRAFORM_PROVIDER_SOURCE)"'","version":"'"$(TERRAFORM_PROVIDER_VERSION)"'"}}],"required_version":"'"$(TERRAFORM_VERSION)"'"}]}' > $(TERRAFORM_WORKDIR)/main.tf.json
	@$(TERRAFORM) -chdir=$(TERRAFORM_WORKDIR) init > $(TERRAFORM_WORKDIR)/terraform-logs.txt 2>&1
	@$(TERRAFORM) -chdir=$(TERRAFORM_WORKDIR) providers schema -json=true > $(TERRAFORM_PROVIDER_SCHEMA) 2>> $(TERRAFORM_WORKDIR)/terraform-logs.txt
	@$(OK) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)

pull-docs:
	@if [ ! -d "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" ]; then \
  		mkdir -p "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" && \
		git clone -c advice.detachedHead=false --depth 1 --filter=blob:none --branch "v$(TERRAFORM_PROVIDER_VERSION)" --sparse "$(TERRAFORM_PROVIDER_REPO)" "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)"; \
	fi
	@git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" sparse-checkout set "$(TERRAFORM_DOCS_PATH)"

generate.init: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs

.PHONY: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs check-terraform-version
# ====================================================================================
# Targets

# NOTE: the build submodule currently overrides XDG_CACHE_HOME in order to
# force the Helm 3 to use the .work/helm directory. This causes Go on Linux
# machines to use that directory as the build cache as well. We should adjust
# this behavior in the build submodule because it is also causing Linux users
# to duplicate their build cache, but for now we just make it easier to identify
# its location in CI so that we cache between builds.
go.cachedir:
	@go env GOCACHE

# Generate a coverage report for cobertura applying exclusions on
# - generated file
cobertura:
	@cat $(GO_TEST_OUTPUT)/coverage.txt | \
		grep -v zz_ | \
		$(GOCOVER_COBERTURA) > $(GO_TEST_OUTPUT)/cobertura-coverage.xml

# Update the submodules, such as the common build scripts.
submodules:
	@git submodule sync
	@git submodule update --init --recursive

# This is for running out-of-cluster locally, and is for convenience. Running
# this make target will print out the command which was used. For more control,
# try running the binary directly with different arguments.
run: go.build
	@$(INFO) Running Crossplane locally out-of-cluster . . .
	@# To see other arguments that can be provided, run the command with --help instead
	UPBOUND_CONTEXT="local" $(GO_OUT_DIR)/provider --debug

# ====================================================================================
# End to End Testing
CROSSPLANE_VERSION = 1.19.0
CROSSPLANE_NAMESPACE = upbound-system
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk

# This target requires the following environment variables to be set:
# - UPTEST_EXAMPLE_LIST, a comma-separated list of examples to test
#   To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately. 
#   You can check the basic implementation here: https://github.com/crossplane/uptest/blob/main/internal/templates/03-delete.yaml.tmpl.
# - UPTEST_CLOUD_CREDENTIALS (optional), multiple sets of AlibabaCloud RAM User credentials specified as key=value pairs.
#   The support keys are currently `DEFAULT` and `PEER`. So, an example for the value of this env. variable is:
#   DEFAULT='[default]
#   alibaba_cloud_access_key_id = REDACTED
#   alibaba_cloud_access_key_secret = REDACTED
#   PEER='[default]
#   alibaba_cloud_access_key_id = REDACTED
#   alibaba_cloud_access_key_secret = REDACTED
#   The associated `ProviderConfig`s will be named as `default` and `peer`.
# - UPTEST_DATASOURCE_PATH (optional), please see https://github.com/crossplane/uptest#injecting-dynamic-values-and-datasource

ACK=./examples/ack/v1alpha1
ACKONE=./examples/ackone/v1alpha1
ALB=./examples/alb/v1alpha1
ALIDNS=./examples/alidns/v1alpha1
CDN=./examples/cdn/v1alpha1
ECS=./examples/ecs/v1alpha1
KMS=./examples/kms/v1alpha1
MESSAGESERVICE=./examples/messageservice/v1alpha1
OSS=./examples/oss/v1alpha1
POLARDB=./examples/polardb/v1alpha1
PRIVATELINK=./examples/privatelink/v1alpha1
QUOTAS=./examples/quotas/v1alpha1
RAM=./examples/ram/v1alpha1
TAIR=./examples/tait/v1alpha1
VPC=./examples/vpc/v1alpha1
UPTEST_EXAMPLE_LIST_ACK=$(ACK)/autoscalingconfig.yaml,$(ACK)/edgekubernetes.yaml,$(ACK)/kubernetesaddon.yaml,$(ACK)/kubernetesnodepool.yaml,$(ACK)/kubernetespermissions.yaml,$(ACK)/managedkubernetes.yaml,$(ACK)/serverlesskubernetes.yaml
UPTEST_EXAMPLE_LIST_ACKONE=$(ACKONE)/cluster.yaml,$(ACKONE)/membershipattachment.yaml
UPTEST_EXAMPLE_LIST_ALB=$(ALB)/acl.yaml,$(ALB)/aclentryattachment.yaml,$(ALB)/ascript.yaml,$(ALB)/healthchecktemplate.yaml,$(ALB)/listener.yaml,$(ALB)/listeneraclattachment.yaml,$(ALB)/loadbalancer.yaml,$(ALB)/loadbalancersecuritygroupattachment.yaml,$(ALB)/loadbalancerzoneshiftedattachment.yaml,$(ALB)/rule.yaml,$(ALB)/securitupolicy.yaml,$(ALB)/servergroup.yaml
UPTEST_EXAMPLE_LIST_ALIDNS=$(ALIDNS)/addreddpool.yaml,$(ALIDNS)/customline.yaml,$(ALIDNS)/domain.yaml,$(ALIDNS)/domainattachment.yaml,$(ALIDNS)/domaingroup.yaml,$(ALIDNS)/gtminstance.yaml,$(ALIDNS)/instance.yaml,$(ALIDNS)/monitorconfig.yaml,$(ALIDNS)/record.yaml
UPTEST_EXAMPLE_LIST_CDN=$(CDN)/domain.yaml,$(CDN)/domainconfig.yaml,$(CDN)/fctrigger.yaml
UPTEST_EXAMPLE_LIST_ECS=$(ECS)/command.yaml,$(ECS)/disk.yaml,$(ECS)/diskattachment.yaml,$(ECS)/instance.yaml,$(ECS)/keypair.yaml,$(ECS)/keypairattachment.yaml,$(ECS)/launchtemplate.yaml,$(ECS)/networkinterface.yaml,$(ECS)/networkinterfaceattachment.yaml,$(ECS)/networkinterfacepermissionspermission.yaml,$(ECS)/securitygroup.yaml,$(ECS)/securitygrouprule.yaml
UPTEST_EXAMPLE_LIST_KMS=$(KMS)/alias.yaml,$(KMS)/key.yaml,$(KMS)/instance.yaml,$(KMS)/secret.yaml
UPTEST_EXAMPLE_LIST_MESSAGESERVICE=$(MESSAGESERVICE)/endpoint.yaml,$(MESSAGESERVICE)/endpointacl.yaml,$(MESSAGESERVICE)/queue.yaml,$(MESSAGESERVICE)/subscription.yaml,$(MESSAGESERVICE)/topic.yaml
UPTEST_EXAMPLE_LIST_OSS=$(OSS)/accesscontrol.yaml,$(OSS)/accountpublicaccessblock.yaml,$(OSS)/bucket.yaml,$(OSS)/bucketaccessmonitor.yaml,$(OSS)/bucketacl.yaml,$(OSS)/bucketcname.yaml,$(OSS)/bucketcnametoken.yaml,$(OSS)/bucketcors.yaml,$(OSS)/bucketdataredundancytransition.yaml,$(OSS)/buckethttpsconfig.yaml,$(OSS)/bucketlogging.yaml,$(OSS)/bucketmetaquery.yaml,$(OSS)/bucketobject.yaml,$(OSS)/bucketpolicy.yaml,$(OSS)/bucketpublicaccessblock.yaml,$(OSS)/bucketreferer.yaml,$(OSS)/bucketreplication.yaml,$(OSS)/bucketrequestpayment.yaml,$(OSS)/bucketserversideencryption.yaml,$(OSS)/bucketstytle.yaml,$(OSS)/buckettransferacceleration.yaml,$(OSS)/bucketuserdefinedlogfields.yaml,$(OSS)/bucketversioning.yaml,$(OSS)/bucketwebsite.yaml,$(OSS)/bucketworm.yaml
UPTEST_EXAMPLE_LIST_POLARDB=$(POLARDB)/account.yaml,$(POLARDB)/accountprivilege.yaml,$(POLARDB)/backuppolicy.yaml,$(POLARDB)/cluster.yaml,$(POLARDB)/clusterendpoint.yaml,$(POLARDB)/database.yaml,$(POLARDB)/endpoint.yaml,$(POLARDB)/endpointaddress.yaml,$(POLARDB)/globaldatabasenetwork.yaml,$(POLARDB)/parametergroup.yaml,$(POLARDB)/primaryendpoint.yaml
UPTEST_EXAMPLE_LIST_PRIVATELINK=$(PRIVATELINK)/vpcendpoint.yaml,$(PRIVATELINK)/vpcendpointconnection.yaml,$(PRIVATELINK)/vpcendpointservice.yaml,$(PRIVATELINK)/vpcendpointserviceresource.yaml,$(PRIVATELINK)/vpcendpointserviceuser.yaml,$(PRIVATELINK)/vpcendpointservicezone.yaml
UPTEST_EXAMPLE_LIST_QUOTAS=$(QUOTAS)/quotaalarm.yaml,$(QUOTAS)/quotaapplication.yaml,$(QUOTAS)/templateapplications.yaml,$(QUOTAS)/templatequota.yaml,$(QUOTAS)/templateservice.yaml
UPTEST_EXAMPLE_LIST_RAM=$(RAM)/accesskey.yaml,$(RAM)/accountalias.yaml,$(RAM)/accountpasswordpolicy.yaml,$(RAM)/group.yaml,$(RAM)/groupmembership.yaml,$(RAM)/grouppolicyattachment.yaml,$(RAM)/loginprofile.yaml,$(RAM)/passwordpolicy.yaml,$(RAM)/policy.yaml,$(RAM)/role.yaml,$(RAM)/rolepolicyattachment.yaml,$(RAM)/samlprovider.yaml,$(RAM)/user.yaml,$(RAM)/usergroupattachment.yaml,$(RAM)/userpolicyattachment.yaml
UPTEST_EXAMPLE_LIST_TAIR=$(TAIR)/account.yaml,$(TAIR)/auditlogconfig.yaml,$(TAIR)/connection.yaml,$(TAIR)/instance.yaml,$(TAIR)/tairinstance.yaml
UPTEST_EXAMPLE_LIST_VPC=$(VPC)/vpc.yaml
UPTEST_EXAMPLE_LIST=$(VPC)/vpc.yaml
uptest: $(UPTEST) $(KUBECTL) $(CHAINSAW)
	@$(INFO) running automated tests
	@KUBECTL=$(KUBECTL) CHAINSAW=$(CHAINSAW) CROSSPLANE_NAMESPACE=$(CROSSPLANE_NAMESPACE) $(UPTEST) e2e "${UPTEST_EXAMPLE_LIST}" --data-source="${UPTEST_DATASOURCE_PATH}" --setup-script=cluster/test/setup.sh --default-conditions="Test" || $(FAIL)
	@$(OK) running automated tests

local-deploy: build controlplane.up local.xpkg.deploy.provider.$(PROJECT_NAME)
	@$(INFO) running locally built provider
	@$(KUBECTL) wait provider.pkg $(PROJECT_NAME) --for condition=Healthy --timeout 5m
	@$(KUBECTL) -n upbound-system wait --for=condition=Available deployment --all --timeout=5m
	@$(OK) running locally built provider

# Family provider build targets
build-provider.%:
	@$(MAKE) build SUBPACKAGES="$$(tr ',' ' ' <<< $*)" LOAD_PACKAGES=true

# Build all family providers (convenience target)
build-family:
	@$(MAKE) build-provider.ack,ackone,alb,alidns,cdn,cloudmonitorservice,ecs,kms,messageservice,oss,polardb,privatelink,quotas,ram,tair,vpc

# Family provider local deployment targets
local-deploy.%: controlplane.up
	@for api in $$(tr ',' ' ' <<< $*); do \
		$(MAKE) local.xpkg.deploy.provider.$(PROJECT_NAME)-$${api}; \
		$(INFO) running locally built $(PROJECT_NAME)-$${api}; \
		$(KUBECTL) wait provider.pkg $(PROJECT_NAME)-$${api} --for condition=Healthy --timeout 5m; \
		$(KUBECTL) -n upbound-system wait --for=condition=Available deployment --all --timeout=5m; \
		$(OK) running locally built $(PROJECT_NAME)-$${api}; \
	done || $(FAIL)

# This target requires the following environment variables to be set:
# - UPTEST_CLOUD_CREDENTIALS, cloud credentials for the provider being tested
# - UPTEST_EXAMPLE_LIST, a comma-separated list of examples to test
# - UPTEST_DATASOURCE_PATH, see https://github.com/crossplane/uptest#injecting-dynamic-values-and-datasource
family-e2e:
	@$(INFO) Removing everything under $(XPKG_OUTPUT_DIR) and $(OUTPUT_DIR)/cache...
	@rm -fR $(XPKG_OUTPUT_DIR)
	@rm -fR $(OUTPUT_DIR)/cache
	@(INSTALL_APIS=""; \
	for m in $$(tr ',' ' ' <<< $${UPTEST_EXAMPLE_LIST}); do \
		$(INFO) Processing the example manifest "$${m}"; \
		for api in $$(sed -nE 's/^apiVersion: *(.+)/\1/p' "$${m}" | cut -d. -f1); do \
		    if [[ $${api} == "v1" ]]; then \
		        $(INFO) v1 is not a valid provider. Skipping...; \
		        continue; \
		    fi; \
			if [[ $${INSTALL_APIS} =~ " $${api} " ]]; then \
				$(INFO) Resource provider $(PROJECT_NAME)-$${api} is already installed. Skipping...; \
				continue; \
			fi; \
			$(INFO) Installing the family resource $(PROJECT_NAME)-$${api} for the test file: $${m}; \
			INSTALL_APIS="$${INSTALL_APIS} $${api} "; \
		done; \
	done; \
	INSTALL_APIS="$$(tr ' ' ',' <<< $${INSTALL_APIS})"; \
	INSTALL_APIS="$$(tr -s ',' <<< "$${INSTALL_APIS}" | sed 's/^,//g' | sed 's/,$$//g')"; \
	$(INFO) Building and deploying resource providers for the short API groups: $${INSTALL_APIS}; \
	$(MAKE) build-provider.$${INSTALL_APIS} local-deploy.$${INSTALL_APIS}) || $(FAIL)
	$(MAKE) uptest

# e2e: Run end-to-end tests with monolith provider
e2e: e2e-monolith

e2e-monolith:
	@$(INFO) Running e2e tests with monolith provider
	@$(MAKE) build-provider.monolith local-deploy.monolith
	@$(MAKE) uptest

# e2e-provider.%: Run end-to-end tests with specific provider families
# Usage: make e2e-provider.vpc or make e2e-provider.ecs,vpc
e2e-provider.%:
	@$(INFO) Running e2e tests with provider families: $*
	@$(MAKE) build-provider.$* local-deploy.$*
	@$(MAKE) uptest

crddiff: $(UPTEST)
	@$(INFO) Checking breaking CRD schema changes
	@for crd in $${MODIFIED_CRD_LIST}; do \
		if ! git cat-file -e "$${GITHUB_BASE_REF}:$${crd}" 2>/dev/null; then \
			echo "CRD $${crd} does not exist in the $${GITHUB_BASE_REF} branch. Skipping..." ; \
			continue ; \
		fi ; \
		echo "Checking $${crd} for breaking API changes..." ; \
		changes_detected=$$($(UPTEST) crddiff revision <(git cat-file -p "$${GITHUB_BASE_REF}:$${crd}") "$${crd}" 2>&1) ; \
		if [[ $$? != 0 ]] ; then \
			printf "\033[31m"; echo "Breaking change detected!"; printf "\033[0m" ; \
			echo "$${changes_detected}" ; \
			echo ; \
		fi ; \
	done
	@$(OK) Checking breaking CRD schema changes

schema-version-diff:
	@$(INFO) Checking for native state schema version changes
	@export PREV_PROVIDER_VERSION=$$(git cat-file -p "${GITHUB_BASE_REF}:Makefile" | sed -nr 's/^export[[:space:]]*TERRAFORM_PROVIDER_VERSION[[:space:]]*:=[[:space:]]*(.+)/\1/p'); \
	echo Detected previous Terraform provider version: $${PREV_PROVIDER_VERSION}; \
	echo Current Terraform provider version: $${TERRAFORM_PROVIDER_VERSION}; \
	mkdir -p $(WORK_DIR); \
	git cat-file -p "$${GITHUB_BASE_REF}:config/schema.json" > "$(WORK_DIR)/schema.json.$${PREV_PROVIDER_VERSION}"; \
	./scripts/version_diff.py config/generated.lst "$(WORK_DIR)/schema.json.$${PREV_PROVIDER_VERSION}" config/schema.json
	@$(OK) Checking for native state schema version changes

# ====================================================================================
# Family Provider Publishing

# publish-family-provider: Publish a smaller scoped provider to Upbound Marketplace
# Usage: make publish-family-provider PROVIDER_SERVICE=vpc
# This will build package and prepare for publishing
publish-family-provider: build-provider.$(PROVIDER_SERVICE)
	@$(INFO) Publishing family provider: $(PROJECT_NAME)-$(PROVIDER_SERVICE)
	@if [ -z "$(PROVIDER_SERVICE)" ]; then \
		echo "Error: PROVIDER_SERVICE must be specified (e.g., PROVIDER_SERVICE=vpc)"; \
		exit 1; \
	fi
	@$(INFO) Step 1: Checking if repository exists...
	@if ! up repository get $(PROJECT_NAME)-$(PROVIDER_SERVICE) >/dev/null 2>&1; then \
		echo "Repository $(PROJECT_NAME)-$(PROVIDER_SERVICE) does not exist."; \
		echo "To create it, run: up repository create $(PROJECT_NAME)-$(PROVIDER_SERVICE) --public"; \
		exit 1; \
	else \
		$(INFO) Repository $(PROJECT_NAME)-$(PROVIDER_SERVICE) exists; \
	fi
	@$(INFO) Step 2: Building package complete
	@$(INFO) Step 3: Package ready for publishing at:
	@echo "  _output/xpkg/$(PLATFORM)/$(PROJECT_NAME)-$(PROVIDER_SERVICE)-$(VERSION).xpkg"
	@$(INFO) Step 4: To publish, run:
	@echo "  crossplane xpkg push $(XPKG_REG_ORGS)/$(PROJECT_NAME)-$(PROVIDER_SERVICE):$(VERSION) -f _output/xpkg/$(PLATFORM)/$(PROJECT_NAME)-$(PROVIDER_SERVICE)-$(VERSION).xpkg"
	@$(OK) Family provider $(PROJECT_NAME)-$(PROVIDER_SERVICE) ready for publishing

.PHONY: cobertura submodules fallthrough run crds.clean publish-family-provider

# ====================================================================================
# Special Targets

define CROSSPLANE_MAKE_HELP
Crossplane Targets:
    cobertura             Generate a coverage report for cobertura applying exclusions on generated files.
    submodules            Update the submodules, such as the common build scripts.
    run                   Run crossplane locally, out-of-cluster. Useful for development.

endef
# The reason CROSSPLANE_MAKE_HELP is used instead of CROSSPLANE_HELP is because the crossplane
# binary will try to use CROSSPLANE_HELP if it is set, and this is for something different.
export CROSSPLANE_MAKE_HELP

crossplane.help:
	@echo "$$CROSSPLANE_MAKE_HELP"

help-special: crossplane.help

.PHONY: crossplane.help help-special publish-family-provider

# TODO(negz): Update CI to use these targets.
vendor: modules.download
vendor.check: modules.check
