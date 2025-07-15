// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	cluster "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ackone/cluster"
	membershipattachment "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ackone/membershipattachment"
)

// Setup_ackone creates all ACKONE controllers for the ACKONE family provider.
func Setup_ackone(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		cluster.Setup,
		membershipattachment.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
