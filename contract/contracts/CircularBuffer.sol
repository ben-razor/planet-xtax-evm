// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

library CircularBuffer {

    struct Buf {
        uint8 idx;
        uint8 numElems;
        uint256[] elems;
    }

    function insert(Buf storage cb, uint256 val) internal {
        cb.idx = wrap(cb.idx + 1, 0, cb.numElems - 1); 
        cb.elems[cb.idx] = val;
    }

    function erase(Buf storage cb, uint8 offset) internal {
        uint8 offs = wrap(cb.idx + offset, 0, cb.numElems - 1); 
        delete cb.elems[offs];
    }

    function read(Buf storage cb, uint8 offset) internal view returns(uint256) {
        uint8 offs = wrap(cb.idx + offset, 0, cb.numElems - 1); 
        return cb.elems[offs];
    }

    function wrap(uint8 val, uint8 start, uint8 end) internal pure returns(uint8) {

        if(val > end) val = start + (val % (end + 1));
        else if(val < start) val = end - ((start - (val + 1)) % end);

        return val;
    }
}

