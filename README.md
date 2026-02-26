## LaunchpadNFT 合约说明

`LaunchpadNFT` 是一个基于 `ERC721A` 的 NFT 发射平台合约，支持：

- **白名单铸造 + 公开铸造**（可分别开关）
- **Merkle 树白名单验证**
- **单钱包最大铸造数量限制**
- **可配置铸造价格、总量上限**
- **预揭示占位图（hidden URI）+ 揭示机制**
- **EIP-2981 版税（Royalty）支持**
- **平台手续费抽成 + 提现逻辑**
- **合约整体暂停 / 恢复**

合约文件：`src/LaunchpadNFT.sol`

---

## 构造函数与初始化参数

```solidity
constructor(
    string memory _name,           // NFT 名称
    string memory _symbol,         // NFT 符号
    uint256 _maxSupply,            // 合约最大供应量
    uint256 _mintPrice,            // 单个 NFT 铸造价格（单位：wei）
    uint256 _maxPerWallet,         // 单钱包最多可铸造数量
    string memory _hiddenURI,      // 未揭示时的统一占位 URI
    address royaltyReceiver,       // 版税接收地址
    uint96 royaltyFee,             // 版税费率（基础点，10000 = 100%）
    uint256 _platformFee,          // 平台抽成费率（基础点，10000 = 100%）
    address _feeReceiver           // 平台费接收地址
)
```

- **`maxSupply`**: 合约生命周期内的最大铸造总量。
- **`mintPrice`**: 每个 NFT 的铸造价格，单位为 wei。
- **`maxPerWallet`**: 单个地址最大可铸造数量（白名单+公开总和）。
- **`hiddenURI`**: 未揭示前所有 token 返回的统一元数据链接。
- **`royaltyReceiver / royaltyFee`**: EIP-2981 版税配置，市场在二级交易时可读取。
- **`platformFee / feeReceiver`**: 提现时按平台费率拆分收益。

---

## 关键状态变量

- **销售控制**
  - `bool public isActive`：总开关，不开启则任何铸造都失败。
  - `bool public whitelistSaleActive`：白名单销售开关。
  - `bool public publicSaleActive`：公开销售开关。

- **数量 & 限制**
  - `uint256 public maxSupply`：最大总供应量。
  - `uint256 public mintPrice`：单价。
  - `uint256 public maxPerWallet`：每个钱包最大铸造数量。
  - `mapping(address => uint256) public mintedPerWallet`：记录地址已铸造数量。

- **URI & 揭示**
  - `string private baseTokenURI`：揭示后的基础 URI。
  - `string public hiddenURI`：未揭示占位 URI。
  - `bool public revealed`：是否已揭示。

- **白名单**
  - `bytes32 public merkleRoot`：Merkle 树根，用于白名单验证。

- **平台费 & 版税**
  - `uint256 public platformFee`：平台费率，万分比。
  - `address public feeReceiver`：平台费接收地址。

---

## 管理员（Owner）函数

这些函数仅合约 `owner` 可调用（继承自 `Ownable`）。

- **销售开关**
  - `setActive(bool _isActive)`：设置合约是否整体激活。
  - `setWhitelistSaleActive(bool _active)`：开启/关闭白名单铸造。
  - `setPublicSaleActive(bool _active)`：开启/关闭公开铸造。

- **白名单配置**
  - `setMerkleRoot(bytes32 _root)`：设置白名单 Merkle 树根。

- **URI 管理**
  - `setBaseURI(string memory _baseURI)`：设置揭示后的基础 URI。
  - `reveal()`：标记为已揭示，`tokenURI` 将从 `baseTokenURI` + `tokenId.json` 返回。

- **合约暂停**
  - `pause()`：暂停合约，所有带 `whenNotPaused` 的操作（包括铸造）都会失败。
  - `unpause()`：恢复合约。

- **提现**
  - `withdraw()`：将合约内 ETH 按平台费率拆分给 `feeReceiver` 和 `owner`。

---

## 用户铸造相关函数

### 白名单铸造

```solidity
function mint(uint256 quantity, bytes32[] memory _proof)
    external
    payable
    nonReentrant
    whenNotPaused
```

调用条件（内部由 `_mintLogic` 校验）：

- `isActive == true`：合约整体已激活。
- `quantity > 0`：铸造数量大于 0。
- `totalSupply() + quantity <= maxSupply`：不会超过最大供应量。
- `msg.value == mintPrice * quantity`：付款金额必须正确。
- `mintedPerWallet[msg.sender] + quantity <= maxPerWallet`：不超过钱包上限。
- `whitelistSaleActive` 或 `publicSaleActive` 至少有一个为 `true`。
- 当 `whitelistSaleActive == true` 且 `merkleRoot != 0` 时：
  - 使用 `MerkleProof.verify(_proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))` 验证调用者在白名单内。

如果上述条件不满足，将抛出对应的自定义错误（见下文）。

### 公开铸造

```solidity
function mint(uint256 quantity)
    external
    payable
    nonReentrant
    whenNotPaused
```

- 不需要传入 Merkle 证明，内部会传入空的 `proof` 数组。
- 公开铸造同样受 `_mintLogic` 的全部检查约束：
  - 必须启用 `isActive`。
  - 必须开启 `publicSaleActive` 或 `whitelistSaleActive`（至少一个）。
  - 价格、总量、钱包上限等约束一致。

---

## 提现逻辑

```solidity
function withdraw() external onlyOwner nonReentrant
```

- 读取当前合约余额 `balance`。
- 计算平台费：`feeAmount = (balance * platformFee) / 10000`。
- 创作者收益：`creatorAmount = balance - feeAmount`。
- 分别向 `feeReceiver` 与 `owner()` 发送 ETH：
  - 任一转账失败则整体回滚，并抛出 `TransferFailed` 错误。

---

## tokenURI 逻辑（揭示机制）

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```

- 若 `tokenId` 不存在：`require(_exists(tokenId), "Nonexistent token");`。
- 若 `revealed == false`：直接返回 `hiddenURI`。
- 若 `revealed == true`：返回  
  `string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"))`。

配合 `reveal()` 和 `setBaseURI()` 即可实现常见的「先占位图，后揭示」的发射逻辑。

---

## 自定义错误（LaunchpadErrors）

铸造和提现过程中会使用一系列自定义错误（位于 `./errors/LaunchpadErrors.sol`）：

- `ContractNotActive`：`isActive` 为 `false` 时尝试铸造。
- `QuantityZero`：铸造数量为 0。
- `MaxSupplyReached`：本次铸造将超过 `maxSupply`。
- `IncorrectPayment`：`msg.value` 与应付金额不匹配。
- `ExceedsWalletLimit`：超出 `maxPerWallet` 限制。
- `SaleNotActive`：白名单和公开销售都未开启。
- `NotInWhitelist`：白名单验证失败。
- `TransferFailed`：提现转账失败。

---

## 部署与使用示例

这里以 Hardhat 为例，说明合约部署与简单调用流程。

### 1. 部署脚本示例

```javascript
// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const LaunchpadNFT = await hre.ethers.getContractFactory("LaunchpadNFT");

  const name = "My Launchpad NFT";
  const symbol = "MLN";
  const maxSupply = 10000;
  const mintPrice = hre.ethers.parseEther("0.05");
  const maxPerWallet = 5;
  const hiddenURI = "ipfs://Qm.../hidden.json";
  const royaltyReceiver = "0xCreatorAddress...";
  const royaltyFee = 500; // 5%
  const platformFee = 500; // 5%
  const feeReceiver = "0xPlatformAddress...";

  const nft = await LaunchpadNFT.deploy(
    name,
    symbol,
    maxSupply,
    mintPrice,
    maxPerWallet,
    hiddenURI,
    royaltyReceiver,
    royaltyFee,
    platformFee,
    feeReceiver
  );

  await nft.waitForDeployment();
  console.log("LaunchpadNFT deployed to:", await nft.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### 2. 配置白名单（链下）

1. 准备白名单地址列表（如 `whitelist.json`）。
2. 在脚本或前端中使用相同的 Merkle 树构造方式，计算 `merkleRoot` 并调用：

```javascript
await contract.setMerkleRoot(merkleRoot);
```

3. 前端在用户铸造时，为当前地址生成对应的 Merkle 证明 `proof`，传入 `mint(quantity, proof)`。

### 3. 启动销售

```javascript
// 激活合约
await contract.setActive(true);

// 开启白名单销售
await contract.setWhitelistSaleActive(true);

// 或开启公开销售
await contract.setPublicSaleActive(true);
```

### 4. 用户前端铸造示例

```javascript
// 白名单铸造
const quantity = 2;
const proof = [...]; // Merkle 证明
const price = await contract.mintPrice();

await contract.mint(quantity, proof, {
  value: price * BigInt(quantity),
});

// 公开铸造（不需要 proof）
await contract.mint(quantity, {
  value: price * BigInt(quantity),
});
```

### 5. 揭示与 URI 设置

```javascript
// 设置揭示后的基础 URI（例如指向 IPFS 文件夹）
await contract.setBaseURI("ipfs://Qm.../metadata/");

// 调用揭示
await contract.reveal();
```

---

## 接口兼容性

合约实现了：

- `ERC721A`：高效批量铸造 NFT。
- `ERC2981`：标准版税接口。

`supportsInterface` 已重写：

```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721A, ERC2981)
    returns (bool)
```

因此主流 NFT 市场在识别标准 NFT 接口与版税方面不会有问题。

---

## 注意事项与扩展建议

- **权限安全**：所有关键参数修改和提现均由 `owner` 执行，部署时请确保 `owner` 地址安全。
- **版税与平台费**：当前实现中，版税仅通过 ERC2981 提供链上声明，具体支付行为由交易市场执行；平台费则由合约在提现时主动分账。
- **白名单逻辑**：当 `whitelistSaleActive == true` 且 `merkleRoot != 0` 时才进行 Merkle 验证，若你希望强制使用白名单，请确保设置好 `merkleRoot`。
- **扩展方向**：可以在此基础上增加多轮销售（不同价格、不同时段）、空投函数、管理员批量铸造、可修改版税配置等功能。

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
