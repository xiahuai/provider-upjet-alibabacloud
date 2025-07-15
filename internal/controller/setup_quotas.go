// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	quotaalarm "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/quotas/quotaalarm"
	quotaapplication "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/quotas/quotaapplication"
	templateapplications "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/quotas/templateapplications"
	templatequota "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/quotas/templatequota"
	templateservice "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/quotas/templateservice"
)

// Setup_quotas creates all QUOTAS controllers for the QUOTAS family provider.
func Setup_quotas(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		quotaalarm.Setup,
		quotaapplication.Setup,
		templateapplications.Setup,
		templatequota.Setup,
		templateservice.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}