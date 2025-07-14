// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	vpcendpoint "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpoint"
	vpcendpointconnection "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpointconnection"
	vpcendpointservice "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpointservice"
	vpcendpointserviceresource "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpointserviceresource"
	vpcendpointserviceuser "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpointserviceuser"
	vpcendpointzone "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/privatelink/vpcendpointzone"
)

// Setup_privatelink creates all PRIVATELINK controllers for the PRIVATELINK family provider.
func Setup_privatelink(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		vpcendpoint.Setup,
		vpcendpointconnection.Setup,
		vpcendpointservice.Setup,
		vpcendpointserviceresource.Setup,
		vpcendpointserviceuser.Setup,
		vpcendpointzone.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}