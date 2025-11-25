// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract HealthConsentToken {

    string public name = "HealthConsentToken";
    string public symbol = "HCT";
    uint8 public decimals = 18;

    mapping(address => uint256) public balances;

    event TokensMinted(address to, uint256 amount);

    function mintForConsent(address patient, uint8 dataType, uint256 durationDays) external {
        uint256 reward = durationDays * 10 * (dataType + 1);
        balances[patient] += reward;

        emit TokensMinted(patient, reward);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
