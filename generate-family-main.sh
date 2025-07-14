#!/bin/bash

# Script to dynamically generate main.go files for all family providers

# Discover family providers from apis directory
FAMILY_PROVIDERS=$(ls apis/ | grep -v v1 | grep -v generate.go | grep -v package | grep -v zz_register.go)

echo "Dynamically discovered family providers:"
for service in $FAMILY_PROVIDERS; do
    echo "  - $service"
done

echo
echo "Generating main.go files..."

# Generate all family providers from template
for service in $FAMILY_PROVIDERS; do
    if [ -n "$service" ]; then
        echo "Generating zz_main.go for $service"
        
        # Use sed to replace template variables in hack/main.go.tmpl (OCI-style approach)
        sed \
            -e "s/{{ \.Service }}/$service/g" \
            hack/main.go.tmpl > "cmd/provider/$service/zz_main.go"
            
        if [ $? -eq 0 ]; then
            echo "  ✓ Generated cmd/provider/$service/zz_main.go"
        else
            echo "  ✗ Failed to generate cmd/provider/$service/zz_main.go"
        fi
    fi
done

# Generate monolith provider from template
echo "Generating zz_main.go for monolith"
sed \
    -e "s/{{ \.Service }}/monolith/g" \
    hack/main.go.tmpl > "cmd/provider/monolith/zz_main.go"
    
if [ $? -eq 0 ]; then
    echo "  ✓ Generated cmd/provider/monolith/zz_main.go"
else
    echo "  ✗ Failed to generate cmd/provider/monolith/zz_main.go"
fi

echo
echo "Generation complete. The following family providers are now ready to build:"
for service in $FAMILY_PROVIDERS; do
    echo "  - make build-provider.$service"
done