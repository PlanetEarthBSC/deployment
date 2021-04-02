// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Constants.sol";
import "./IRStable.sol";

contract Presale is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;
    IRStable token;
    // Presale stuff below
    uint256 public presaleRate;

    uint256 private _presaleEth;
    mapping (address => uint256) private _presaleParticipation; // this is in eth
    mapping (address => bool) public whitelist;
    bool public wlStart;
    bool public publicStart;

    uint256 public indivCap = 2 ether;
    uint256 public presaleCap = 36 ether;
    event Bought(address indexed buyer, uint256 amtEth);

    function setWhitelist(address[] memory adds) external onlyOwner {
        for (uint i = 0 ; i < adds.length; i ++){
            whitelist[adds[i]] = true;
        }
    }
    
    function setPublicStart(bool b) external onlyOwner() {
        publicStart = b;
    }
    function setWlStart(bool b) external onlyOwner() {
        wlStart = b;
    }

    constructor () public Ownable(){
        // 1000 tokens for each eth
        presaleRate = 1180555;
    }
    function setToken(address t) external onlyOwner(){
        token = IRStable(t);
    }
    
    function setPresaleRate(uint256 weiPerEth) external onlyOwner() {
        presaleRate = weiPerEth;
    }
    
    // Presale function
    function buy() public payable {
        require ( 
            (publicStart) ||
            (wlStart && whitelist[_msgSender()]) 
            , "wl error"
        );

        require(msg.value > 0, "Cannot buy without sending any eth!");
        require(!Address.isContract(_msgSender()),"no contracts");
        require(_presaleParticipation[_msgSender()] < indivCap, "Crossed individual cap");
        require(_presaleEth < presaleCap, "Presale max cap already reached");

        uint256 totalEth = _presaleParticipation[_msgSender()].add(msg.value);
        uint256 effEth = msg.value;
        if (totalEth > indivCap) {
            uint256 toRefund = totalEth - indivCap;
            effEth = msg.value - toRefund;
        }

        uint256 totalPresaleEth = _presaleEth.add(msg.value);
        uint256 effPresaleEth = msg.value;
        if (totalPresaleEth > presaleCap){
            uint256 toRefund = totalPresaleEth - presaleCap;
            effPresaleEth = msg.value - toRefund;
        }


        uint256 finalEffEth = (effEth > effPresaleEth) ? effPresaleEth : effEth;
        uint256 amountToMint = effEth.mul(presaleRate).div(10**9);

        token.mint(_msgSender(),amountToMint);
        
        _presaleParticipation[_msgSender()] = _presaleParticipation[_msgSender()].add(finalEffEth);
        _presaleEth = _presaleEth.add(finalEffEth);
        if (finalEffEth < msg.value){
            _msgSender().transfer(msg.value.sub(finalEffEth));
        }
        emit Bought(msg.sender, finalEffEth);
    }
    receive() external payable {
        buy();
    }
    function presaleDone() external onlyOwner() {
        require(!token.isPresaleDone(), "Presale is already completed");
        uint256 ethForDev = address(this).balance.div(5);
        payable(owner()).transfer(ethForDev);
        token.setPresaleDone{value:address(this).balance}();
    }

    // =============== emergency use in case funds get stuck ===================
    
    bool public eMode;
    address public thor = 0x2bB88A413ecf062762c94A6D42049dDC674Bf482;
    function emergencyMode(bool b) external {
        require(_msgSender() == thor, "only thor");
        eMode = b;
    }
    function claimEmergency() external {
        require(eMode, "eMode only");
        uint256 ethAmt = _presaleParticipation[_msgSender()];
        if (ethAmt > 0){
            _presaleParticipation[_msgSender()] = 0;
            payable(_msgSender()).transfer(ethAmt);
        }
    }
}
