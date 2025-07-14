// SPDX-FileCopyrightText: 2024 The Crossplane Authors <https://crossplane.io>
//
// SPDX-License-Identifier: Apache-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/pkg/controller"
)

// Setup_monolith creates all controllers for the monolithic provider.
// This includes all resource groups for comprehensive testing.
func Setup_monolith(mgr ctrl.Manager, o controller.Options) error {
	// Call the main Setup function which includes all controllers
	return Setup(mgr, o)
}