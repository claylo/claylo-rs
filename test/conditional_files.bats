#!/usr/bin/env bats
# test/conditional_files.bats
# Fast tests for conditional file inclusion/exclusion (no cargo build)

load 'test_helper'

# =============================================================================
# GitHub Options
# =============================================================================

@test "has_github=false excludes .github directory" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-no-github" "minimal.yml" \
        "has_github=false" \
        "has_security_md=false" \
        "has_claude=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" "Cargo.toml"
    assert_no_file_in_project "$output_dir" ".github"
    assert_no_file_in_project "$output_dir" ".github/workflows"
    assert_no_file_in_project "$output_dir" "SECURITY.md"
}

@test "has_github=true with templates disabled excludes template dirs" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-github-no-templates" "minimal.yml" \
        "has_github=true" \
        "has_issue_templates=false" \
        "has_pr_templates=false" \
        "has_security_md=true" \
        "has_claude=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" ".github"
    assert_file_in_project "$output_dir" ".github/workflows"
    assert_file_in_project "$output_dir" "SECURITY.md"
    assert_no_file_in_project "$output_dir" ".github/ISSUE_TEMPLATE"
    assert_no_file_in_project "$output_dir" ".github/PULL_REQUEST_TEMPLATE"
}

# =============================================================================
# Dotfiles
# =============================================================================

@test "dotfiles enabled includes .yamlfmt, .yamllint, .editorconfig, .envrc" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-dotfiles-on" "minimal.yml" \
        "has_yamlfmt=true" \
        "has_yamllint=true" \
        "has_editorconfig=true" \
        "has_env_files=true" \
        "has_github=false" \
        "has_claude=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" ".yamlfmt"
    assert_file_in_project "$output_dir" ".yamllint"
    assert_file_in_project "$output_dir" ".editorconfig"
    assert_file_in_project "$output_dir" ".env.rust"
    assert_file_in_project "$output_dir" ".envrc"
}

@test "dotfiles disabled excludes dotfiles" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-dotfiles-off" "minimal.yml" \
        "has_yamlfmt=false" \
        "has_yamllint=false" \
        "has_editorconfig=false" \
        "has_env_files=false" \
        "has_github=false" \
        "has_claude=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" "Cargo.toml"
    assert_no_file_in_project "$output_dir" ".yamlfmt"
    assert_no_file_in_project "$output_dir" ".yamllint"
    assert_no_file_in_project "$output_dir" ".editorconfig"
    assert_no_file_in_project "$output_dir" ".env.rust"
    assert_no_file_in_project "$output_dir" ".envrc"
}

# =============================================================================
# Claude Integration
# =============================================================================

@test "has_claude=false excludes .claude directory" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-no-claude" "minimal.yml" \
        "has_claude=false" \
        "has_github=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" "Cargo.toml"
    assert_no_file_in_project "$output_dir" ".claude"
    assert_no_file_in_project "$output_dir" ".claude/CLAUDE.md"
    assert_no_file_in_project "$output_dir" ".claude/skills"
    assert_no_file_in_project "$output_dir" ".claude/commands"
    assert_no_file_in_project "$output_dir" ".claude/rules"
}

@test "has_claude=true with skills disabled excludes skills dir" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-claude-no-skills" "minimal.yml" \
        "has_claude=true" \
        "has_claude_skills=false" \
        "has_claude_commands=true" \
        "has_claude_rules=true" \
        "has_github=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" ".claude"
    assert_file_in_project "$output_dir" ".claude/CLAUDE.md"
    assert_file_in_project "$output_dir" ".claude/commands"
    assert_file_in_project "$output_dir" ".claude/rules"
    assert_no_file_in_project "$output_dir" ".claude/skills"
}

@test "selective skills includes only requested skills" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-skills-selective" "minimal.yml" \
        "has_claude=true" \
        "has_claude_skills=true" \
        "has_claude_commands=false" \
        "has_claude_rules=false" \
        "has_skill_markdown_authoring=false" \
        "has_skill_capturing_decisions=true" \
        "has_skill_using_git=false" \
        "has_github=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" ".claude/skills/capturing-decisions"
    assert_no_file_in_project "$output_dir" ".claude/skills/markdown-authoring"
    assert_no_file_in_project "$output_dir" ".claude/skills/using-git"
    assert_no_file_in_project "$output_dir" ".claude/commands"
    assert_no_file_in_project "$output_dir" ".claude/rules"
}

# =============================================================================
# Markdown Linting
# =============================================================================

@test "has_md=true includes .markdownlint.yaml" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-md-on" "minimal.yml" \
        "has_md=true" \
        "has_md_strict=false" \
        "has_github=false" \
        "has_claude=false" \
        "has_just=true" \
        "has_agents_md=false" \
        "has_gitattributes=false")

    assert_file_in_project "$output_dir" ".markdownlint.yaml"
    assert_file_in_project "$output_dir" ".justfile"
}

@test "has_md=false excludes .markdownlint.yaml" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-md-off" "minimal.yml" \
        "has_md=false" \
        "has_github=false" \
        "has_claude=false" \
        "has_just=true" \
        "has_agents_md=false" \
        "has_gitattributes=false")

    assert_file_in_project "$output_dir" ".justfile"
    assert_no_file_in_project "$output_dir" ".markdownlint.yaml"
}

# =============================================================================
# Core Files
# =============================================================================

@test "core files disabled excludes AGENTS.md, .justfile, .gitattributes" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-core-off" "minimal.yml" \
        "has_agents_md=false" \
        "has_just=false" \
        "has_gitattributes=false" \
        "has_github=false" \
        "has_claude=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" "Cargo.toml"
    assert_no_file_in_project "$output_dir" "AGENTS.md"
    assert_no_file_in_project "$output_dir" ".justfile"
    assert_no_file_in_project "$output_dir" ".gitattributes"
}

# =============================================================================
# Hook Systems
# =============================================================================

@test "hook_system=none excludes all hook configs" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-hook-none" "minimal.yml" \
        "hook_system=none" \
        "has_github=false" \
        "has_claude=false" \
        "has_just=false" \
        "has_agents_md=false" \
        "has_gitattributes=false" \
        "has_md=false")

    assert_file_in_project "$output_dir" "Cargo.toml"
    assert_no_file_in_project "$output_dir" ".pre-commit-config.yaml"
    assert_no_file_in_project "$output_dir" "lefthook.yml"
}

# =============================================================================
# Template Sanity Checks
# =============================================================================

@test "no unresolved template variables in filenames" {
    local output_dir
    output_dir=$(generate_project "sanity-templates" "standard.yml")

    run find "$output_dir" -name "*{{*"
    assert_output ""
}

@test "no __skip_ files in output" {
    local output_dir
    output_dir=$(generate_project "sanity-skip" "standard.yml")

    run find "$output_dir" -name "*__skip_*"
    assert_output ""
}
