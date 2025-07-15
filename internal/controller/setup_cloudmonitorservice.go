// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	alarmcontactgroup "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/cloudmonitorservice/alarmcontactgroup"
)

// Setup_cloudmonitorservice creates all CLOUDMONITORSERVICE controllers for the CLOUDMONITORSERVICE family provider.
func Setup_cloudmonitorservice(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		alarmcontactgroup.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
