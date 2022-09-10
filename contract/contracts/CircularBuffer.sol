// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

library CircularBuffer {

    struct Buf {
        uint8 idx;
        uint8 numElems;
        uint256[] elems;
    }

    function insert(Buf storage cb, uint256 val) internal {
        int8 idx = wrap(int8(cb.idx) + 1, 0, int8(cb.numElems) - 1); 
        cb.idx = uint8(idx);
        cb.elems[cb.idx] = val;
    }

    function erase(Buf storage cb, int8 offset) internal {
        int8 offs = wrap(int8(cb.idx) - offset, 0, int8(cb.numElems) - 1); 
        delete cb.elems[uint8(offs)];
    }

    function read(Buf storage cb, int8 offset) internal view returns(uint256) {
        int8 offs = wrap(int8(cb.idx) - offset, 0, int8(cb.numElems) - 1); 
        return cb.elems[uint8(offs)];
    }

    function wrap(int8 val, int8 start, int8 end) internal pure returns(int8) {

        if(val > end) val = start + (val % (end + 1));
        else if(val < start) val = end - ((start - (val + 1)) % end);

        return val;
    }
}

