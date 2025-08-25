// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	alias "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/alias"
	asyncinvokeconfig "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/asyncinvokeconfig"
	concurrencyconfig "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/concurrencyconfig"
	customdomain "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/customdomain"
	function "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/function"
	functionversion "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/functionversion"
	layerversion "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/layerversion"
	provisionconfig "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/provisionconfig"
	trigger "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/trigger"
	vpcbinding "github.com/crossplane-contrib/provider-alibabacloud/internal/controller/fcv3/vpcbinding"
)

// Setup_fcv3 creates all controllers with the supplied logger and adds them to
// the supplied manager.
func Setup_fcv3(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		alias.Setup,
		asyncinvokeconfig.Setup,
		concurrencyconfig.Setup,
		customdomain.Setup,
		function.Setup,
		functionversion.Setup,
		layerversion.Setup,
		provisionconfig.Setup,
		trigger.Setup,
		vpcbinding.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
