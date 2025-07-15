// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	domain "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/cdn/domain"
	domainconfig "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/cdn/domainconfig"
	fctrigger "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/cdn/fctrigger"
)

// Setup_cdn creates all CDN controllers for the CDN family provider.
func Setup_cdn(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		domain.Setup,
		domainconfig.Setup,
		fctrigger.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
