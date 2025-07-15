// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"

	autoscalingconfig "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/autoscalingconfig"
	edgekubernetes "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/edgekubernetes"
	kubernetes "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/kubernetes"
	kubernetesaddon "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/kubernetesaddon"
	kubernetesnodepool "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/kubernetesnodepool"
	kubernetespermissions "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/kubernetespermissions"
	managedkubernetes "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/managedkubernetes"
	serverlesskubernetes "github.com/crossplane-contrib/provider-upjet-alibabacloud/internal/controller/ack/serverlesskubernetes"
)

// Setup_ack creates all ACK controllers for the ACK family provider.
func Setup_ack(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		autoscalingconfig.Setup,
		edgekubernetes.Setup,
		kubernetes.Setup,
		kubernetesaddon.Setup,
		kubernetesnodepool.Setup,
		kubernetespermissions.Setup,
		managedkubernetes.Setup,
		serverlesskubernetes.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
