#!/bin/bash

# Terraform Module Validation Script

echo "🔍 Validating Terraform modules..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to validate a module
validate_module() {
    local module_path=$1
    local module_name=$2
    
    echo -e "\n📁 Validating ${YELLOW}${module_name}${NC} module..."
    
    if [ -d "$module_path" ]; then
        cd "$module_path"
        
        # Check if required files exist
        if [ -f "main.tf" ] && [ -f "variables.tf" ] && [ -f "outputs.tf" ]; then
            echo -e "  ✅ Required files present"
        else
            echo -e "  ❌ Missing required files (main.tf, variables.tf, outputs.tf)"
            return 1
        fi
        
        # Validate Terraform syntax
        if terraform validate > /dev/null 2>&1; then
            echo -e "  ✅ Terraform syntax valid"
        else
            echo -e "  ❌ Terraform syntax errors:"
            terraform validate
            return 1
        fi
        
        # Format check
        if terraform fmt -check > /dev/null 2>&1; then
            echo -e "  ✅ Terraform formatting correct"
        else
            echo -e "  ⚠️  Terraform formatting issues (run 'terraform fmt')"
        fi
        
        cd - > /dev/null
        return 0
    else
        echo -e "  ❌ Module directory not found: $module_path"
        return 1
    fi
}

# Validate each module
modules=(
    "modules/networking:Networking"
    "modules/eks:EKS"
    "modules/storage:Storage"
    "modules/messaging:Messaging"
)

failed_modules=0

for module in "${modules[@]}"; do
    IFS=':' read -r path name <<< "$module"
    if ! validate_module "$path" "$name"; then
        ((failed_modules++))
    fi
done

# Validate production environment
echo -e "\n📁 Validating ${YELLOW}Production Environment${NC}..."
if validate_module "environments/prod" "Production"; then
    echo -e "  ✅ Production environment valid"
else
    echo -e "  ❌ Production environment has issues"
    ((failed_modules++))
fi

# Summary
echo -e "\n📊 ${YELLOW}Validation Summary${NC}"
if [ $failed_modules -eq 0 ]; then
    echo -e "✅ All modules passed validation!"
    exit 0
else
    echo -e "❌ $failed_modules module(s) failed validation"
    exit 1
fi