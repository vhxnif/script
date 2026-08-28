/**
 * Nushell Extension for Pi Coding Agent
 *
 * 注册一个 `nu` 工具，让 AI 可以使用 Nushell 语法和结构化数据处理能力。
 * 同时在 system prompt 中注入 nushell 指导，帮助 AI 了解何时以及如何使用 nu。
 *
 * 用法：
 *   pi -e ./index.ts
 *
 * 或安装到：
 *   ~/.pi/agent/extensions/nushell/index.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ============================================================
// 启动检测：nu 是否可用
// ============================================================
let nuAvailable = false;
let nuVersion = "";

async function detectNu(pi: ExtensionAPI): Promise<boolean> {
	try {
		const result = await pi.exec("nu", ["--version"]);
		if (result.code === 0) {
			nuVersion = result.stdout?.trim() || "unknown";
			return true;
		}
		return false;
	} catch {
		return false;
	}
}

// ============================================================
// Nushell 指导内容（注入到 system prompt）
// ============================================================
const NUSHELL_GUIDANCE = `
## Nushell (nu) 工具使用指导

你有一个 \`nu\` 工具可以直接执行 Nushell 命令。Nushell 是一个现代化的 shell，核心特点是**结构化数据**——每个命令的输出都是带类型的表格，而不是纯文本。

### nu vs bash：何时用哪个？

**优先使用 nu 的场景：**
- 处理 JSON、CSV、YAML 等结构化数据（nu 原生解析，比 bash + jq 更简洁）
- 需要对文件列表进行过滤、排序、分组、统计
- 数据管道操作——where（过滤）、select（选择列）、sort-by（排序）、group-by（分组）
- 网络请求后解析响应数据（\`http get\` 返回结构化数据）
- 批量文件操作（重命名、转换等）

**继续用 bash 的场景：**
- 简单的单条命令（mkdir、cp、mv、rm 等基础文件操作）
- 执行 npm/pip/cargo 等包管理命令
- git 操作
- docker/kubectl 等 CLI 工具
- 需要 POSIX shell 特性的脚本（&&、||、变量扩展等）

### nu 核心语法速查

nu 不是 POSIX shell！以下是一些关键差异和惯用法：

\`\`\`nu
# 列出所有 .ts 文件，按大小排序
ls | where type == file and name =~ '\\.ts$' | sort-by size | reverse

# 等价于 bash:  ls -la | grep ".ts"
ls | where name =~ '\\.ts'

# 读取 JSON 文件并提取字段
open package.json | get dependencies | columns

# 读取 CSV 统计
open data.csv | group-by category | each { |g| { category: $g.category, count: ($g | length) } }

# 网络请求
http get https://api.example.com/data | get items | first 5

# 字符串处理
"hello world" | str upcase | str replace "O" "0" --all

# 遍历
ls *.ts | each { |file| { name: $file.name, size_kb: ($file.size / 1KB | math round) } }

# 条件过滤
ps | where mem > 100MB | sort-by cpu | last 10
\`\`\`

### 注意事项

1. **nu 不是 POSIX shell**：不支持 \`&&\`、\`||\`、\`>\` 重定向等 bash 语法。用 \`;\` 分隔命令或使用 nu 原生管道。
2. **字符串引用**：单引号 \`'...'\` 是纯字符串，双引号 \`"..."\` 支持变量插值 \`$variable\`。
3. **命令参数**：nu 使用 \`--flag value\` 风格，不是 \`-f value\`（短选项较少）。
4. **管道**：每个命令输出的是结构化表格，不是文本流。用 \`| get column\` 而不是 \`| awk '{print $1}'\`。
5. **错误处理**：nu 的 \`try { ... } catch { ... }\` 比 bash 的 \`||\` 更清晰。
6. **内置帮助**：不确定某个 nu 命令的用法时，用 \`help <命令名>\` 查看文档。\`help commands\` 列出所有可用命令，\`help --find <关键词>\` 搜索相关命令。`;

// ============================================================
// 扩展入口
// ============================================================
export default async function (pi: ExtensionAPI) {
	// --- 启动检测 ---
	nuAvailable = await detectNu(pi);

	if (!nuAvailable) {
		console.warn(
			"[nushell] Nushell (nu) 未在 PATH 中找到。nu 工具将不会被注册。",
		);
		pi.on("session_start", async (_event, ctx) => {
			ctx.ui.notify(
				"Nushell (nu) 未安装或不在 PATH 中，nu 工具不可用。",
				"warning",
			);
		});
		return;
	}

	// --- 注册 nu 工具 ---
	pi.registerTool({
		name: "nu",
		label: "Nu",
		description:
			"通过 Nushell (nu) 执行命令。Nushell 以结构化数据为核心，所有命令输出都是带类型的表格而非纯文本。" +
			"适用于：JSON/CSV/YAML 数据处理、文件列表过滤与统计、批量操作、网络请求解析等场景。" +
			"不适用于：简单文件操作（mkdir/cp/mv）、git、包管理器等传统 CLI 调用——这些请使用 bash 工具。",
		promptSnippet: "通过 Nushell 执行命令，输出结构化数据表格",
		promptGuidelines: [
			"使用 nu 工具处理 JSON/CSV/YAML 结构化数据、文件列表过滤与统计、网络请求解析等场景。nu 的管道传递的是带类型的结构化表格，而非纯文本流。",
			"nu 不是 POSIX shell——不支持 &&、||、> 重定向等 bash 语法。用 ; 分隔命令，或用 nu 原生管道 (|) 和错误处理 (try/catch)。",
			"对于简单文件操作、git、包管理器等传统 CLI 调用，继续使用 bash 工具。",
		],
		parameters: Type.Object({
			command: Type.String({
				description: "要执行的 Nushell 命令。使用 nu 语法而非 bash 语法。",
			}),
			timeout: Type.Optional(
				Type.Number({
					description: "命令超时时间（秒），默认无超时限制",
				}),
			),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
			const timeout = params.timeout ? params.timeout * 1000 : undefined;

			const result = await pi.exec("nu", ["-c", params.command], {
				timeout,
				signal,
			});

			const text = [
				result.stdout ? result.stdout.trim() : "",
				result.stderr ? `\n[stderr]\n${result.stderr.trim()}` : "",
			]
				.filter(Boolean)
				.join("\n");

			return {
				content: [
					{
						type: "text",
						text: text || `(nu 命令完成，退出码: ${result.code})`,
					},
				],
				details: {
					exitCode: result.code,
					truncated: result.truncated ?? false,
				} as Record<string, unknown>,
			};
		},
	});

	// --- 注入 system prompt 指导 ---
	pi.on("before_agent_start", async (event) => {
		const hasNuTool = event.systemPromptOptions.selectedTools?.includes("nu");

		// 只有当 nu 工具在活跃工具列表中时才注入指导
		// （如果用户禁用了 nu 工具，就不要注入指导）
		if (!hasNuTool) return;

		return {
			systemPrompt: event.systemPrompt + NUSHELL_GUIDANCE,
		};
	});

	// --- /nu 命令：显示 nu 版本和状态 ---
	pi.registerCommand("nu", {
		description: "显示 Nushell (nu) 版本和状态",
		handler: async (_args, ctx) => {
			const activeTools = pi.getActiveTools();
			const isActive = activeTools.includes("nu");
			ctx.ui.notify(
				[
					`Nushell (nu) — v${nuVersion}`,
					`状态: ${isActive ? "✓ 已启用" : "✗ 已禁用（用 /tools 切换）"}`,
					`路径: /opt/homebrew/bin/nu`,
				].join("\n"),
				"info",
			);
		},
	});
}
