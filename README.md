# Dojo

Dojo is a universal framework and registry for AI agent capabilities. It defines a standard, portable format for skills, context, and capabilities that any agent, framework, or LLM can discover and use.

## Structure

- **`schema/`**: JSON Schema definitions for Dojo nodes (`node.json`).
- **`nodes/`**: The core Dojo capability hierarchy containing instances of `ecosystem`, `standard`, `skill`, `context`, and `sub` nodes.
- **`skills/`**: Agent skill bundles following the Agent Skills spec (e.g., `dojo-node-creator`, `dojo-node-author`) that agents can load directly to interact with the registry.
- **`sdk/`**: SDKs for developers to interact with the Dojo registry.
- **`server/`**: The Dojo backend registry / API service.
- **`web/`**: The web frontend interface for browsing and interacting with the Dojo registry.
- **`tests/`**: Unit and integration tests for nodes and skills.
- **`docker/`**: Containerization and deployment assets.

## Usage

Agents can search the Dojo registry and load nodes dynamically to learn how to interact with new APIs, smart contracts, or CLI tools. Each node contains deep, actionable context, wiki-links, and portable `SKILL.md` configurations.
