# Installation Guide

This guide provides step-by-step instructions to install and set up a self-hosted source control system using Azure services.

## Prerequisites
Before you begin, ensure you have the following:
- An active Azure account
- VS Code installed with the Remote - Containers extension


## Steps to Install
1. **Clone the Repository**
   ```bash
   git clone somerepositoryurl.git
   cd somerepository
   ```
2. **Open in VS Code**
   - Open VS Code and use the "Remote - Containers" extension to open the cloned repository in a container.
3. **Build the Development Container**
   - VS Code will automatically build the development container based on the provided Dockerfile and configuration.
4. **Authenticate to Azure and select the subscription**
   - Sign in before running OpenTofu.
   ```bash
   az login
   ```
