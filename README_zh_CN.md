# MoonSCIM

[English](README.md) · [架构](docs/ARCHITECTURE.md) · [安全边界](docs/SECURITY.md) · [测试](docs/TESTING.md)

MoonSCIM 是 MoonBit 生态中的可移植 SCIM 2.0 语义核心。它提供模式、资源校验、过滤器、PATCH、分页、Bulk、发现资源和 JSON 编解码能力，同时不绑定 HTTP 框架、数据库、身份提供商或部署平台。

## 生态价值与通用场景

SCIM 用于在不同系统之间自动同步身份。MoonSCIM 可服务于员工入职/离职、SaaS 多租户账号开通、群组与角色同步、教育和医疗目录、开发者组织同步、设备身份目录、LDAP-SCIM 网关、协议一致性工具以及测试替身。核心模块只处理确定性内存语义，因此同一套能力可复用于 Native、JavaScript 和 WebAssembly 应用。

## 已实现能力

- RFC 7643 风格属性定义、扩展模式、注册表、类型/基数/规范值校验，以及按创建、替换、PATCH、响应区分的可变性校验。
- RFC 7644 过滤器词法与优先级解析、类型化求值、复杂多值 `valuePath`、大小写不敏感属性路径和扩展 URN 路径。
- 原子化 `add`、`replace`、`remove`，包括过滤后多值复杂属性更新。
- 属性投影、稳定排序、索引分页及 RFC 9865 风格的查询绑定游标分页。
- Bulk 请求校验、稳定拓扑排序、环检测、前向 `bulkId` 引用及递归替换。
- 有输入长度、嵌套深度和节点数上限的确定性 JSON 转换，并拒绝大小写变体的重复 SCIM 属性。
- User、Group、Enterprise User 标准模式，以及 ListResponse、Error、ServiceProviderConfig、ResourceType、Schema 发现资源。
- 四后端可移植核心、Native CLI 和三个可执行端到端示例。

## 快速开始

```sh
git clone https://github.com/oyjh0381/MoonSCIM.git
cd MoonSCIM
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/saas_provisioning --target native
```

典型调用：

```mbt
let resource = @codec.decode_object(json_text).unwrap()
let report = @validation.validate_resource(
  @standard.standard_registry(),
  @standard.user_schema_id(),
  resource,
  @validation.Create,
)
let filter = @filter.compile_filter("active eq true").unwrap()
println(report.is_valid() && filter.matches(resource))
```

## CLI 与示例

```sh
moon run cmd/main --target native -- version
moon run cmd/main --target native -- discover
moon run cmd/main --target native -- validate '{"schemas":["urn:ietf:params:scim:schemas:core:2.0:User"],"userName":"alice"}'
moon run cmd/main --target native -- match 'active eq true' '{"active":true}'

moon run examples/saas_provisioning --target native
moon run examples/hr_lifecycle --target native
moon run examples/group_sync --target native
```

三个示例分别证明 SaaS 入职配置、HR 离职变更和含前向依赖的群组同步可以实际执行，而不是仅停留在接口说明中。

## 支持范围

| 能力 | v0.1 状态 | 明确边界 |
| --- | --- | --- |
| RFC 7643 核心资源 | 已实现 | ID、时间戳和版本由宿主提供 |
| RFC 7644 Filter/PATCH | 已实现 | 持久化与事务由适配器提供 |
| RFC 7644 Bulk | 已实现规划与引用解析 | HTTP 执行、回滚、限流不在核心内 |
| 发现资源与消息 | 已实现值构造 | 路由和内容协商不在核心内 |
| 索引分页 | 已实现 | 数据库下推由存储适配器负责 |
| RFC 9865 游标分页 | 已实现 | 内置令牌不是 MAC，跨信任边界必须签名或加密 |
| RFC 9944 设备扩展 | 暂未实现 | 计划作为独立扩展包 |
| RFC 9967 SCIM 事件 | 暂未实现 | 需要事件传输及安全配置 |

过滤器当前对字符串执行大小写不敏感比较；若应用需要严格执行自定义模式中的 `caseExact`，应在存储查询或宿主比较适配器中补充模式感知策略。MoonSCIM 不提供 HTTP 服务、OAuth/OIDC、TLS、授权、数据库、唯一性事务、审计落库、密钥存储或个人数据保留策略。

## 工程质量

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --deny-warn
moon info
python tools/count_moonbit_loc.py --minimum 4000
```

当前仓库在 wasm、wasm-gc、JavaScript、Native 四个目标上各有 87 项测试通过，有效非注释 MoonBit 代码超过 5,000 行，并通过 CI 校验格式、全目标检查、测试、Native 构建、可执行示例、生成接口及 4,000 行规模门槛。

MoonSCIM 是依据 IETF RFC 7643、7644、9865 行为重新实现的原创项目，不移植其他 SCIM SDK。选题检索证据见 [`docs/ecosystem-review.md`](docs/ecosystem-review.md)，发布前会再次检索 mooncakes.io。

项目采用 Apache License 2.0；规范与对比来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
