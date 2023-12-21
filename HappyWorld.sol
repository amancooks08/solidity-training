// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;


contract MyContract {

    address owner;
    bool public isHappy; 

    /**
   * @dev Tells if owner is Happy
   */
    constructor(address _owner) {
        owner = _owner;
    }

    function tell(address _add) public {
        if(_add == owner) {
            isHappy = true;
        } else {
            isHappy = false;
        }
    }
}