/*
Copyright 2021 Upbound Inc.
*/

package config

import (
	// Note(turkenh): we are importing this to embed provider schema document
	_ "embed"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/fcv3"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/slb"

	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/ack"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/ackone"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/alb"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/alidns"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/cdn"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/cloudmonitorservice"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/ecs"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/kms"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/messageservice"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/oss"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/polardb"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/privatelink"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/quotas"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/ram"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/tair"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/config/vpc"
	"github.com/crossplane-contrib/provider-upjet-alibabacloud/hack"
	"github.com/crossplane/upjet/pkg/registry/reference"

	ujconfig "github.com/crossplane/upjet/pkg/config"
)

const (
	resourcePrefix = "alicloud"
	modulePath     = "github.com/crossplane-contrib/provider-upjet-alibabacloud"
)

//go:embed schema.json
var providerSchema string

//go:embed provider-metadata.yaml
var providerMetadata string

// GetProvider returns provider configuration
func GetProvider() *ujconfig.Provider {
	defaultResourceOptions := []ujconfig.ResourceOption{
		ExternalNameConfigurations(),
		RegionAddition(),
		IdentifierAssignedByAlibabaCloud(),
		KnownReferences(),
		NamePrefixRemoval(),
		AddExternalTagsField(),
		DocumentationForTags(),
	}

	pc := ujconfig.NewProvider([]byte(providerSchema), resourcePrefix, modulePath, []byte(providerMetadata),
		ujconfig.WithShortName("alibabacloud"),
		ujconfig.WithRootGroup("alibabacloud.crossplane.io"),
		ujconfig.WithIncludeList(ExternalNameConfigured()),
		ujconfig.WithReferenceInjectors([]ujconfig.ReferenceInjector{reference.NewInjector(modulePath)}),
		ujconfig.WithFeaturesPackage("internal/features"),
		ujconfig.WithMainTemplate(hack.MainTemplate),
		ujconfig.WithDefaultResourceOptions(defaultResourceOptions...))

	for _, configure := range []func(provider *ujconfig.Provider){
		// add custom config functions
		ack.Configure,
		ackone.Configure,
		alb.Configure,
		alidns.Configure,
		cdn.Configure,
		cloudmonitorservice.Configure,
		ecs.Configure,
		fcv3.Configure,
		kms.Configure,
		messageservice.Configure,
		oss.Configure,
		polardb.Configure,
		privatelink.Configure,
		quotas.Configure,
		ram.Configure,
		slb.Configure,
		tair.Configure,
		vpc.Configure,
	} {
		configure(pc)
	}

	pc.ConfigureResources()
	return pc
}
