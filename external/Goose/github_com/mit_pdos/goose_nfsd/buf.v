(* autogenerated from github.com/mit-pdos/goose-nfsd/buf *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.goose_nfsd.addr.
From Goose Require github_com.mit_pdos.goose_nfsd.common.
From Goose Require github_com.mit_pdos.goose_nfsd.util.
From Goose Require github_com.tchajed.marshal.

(* buf.go *)

(* A buf holds a disk object (inode, a bitmap bit, or disk block) *)
Module Buf.
  Definition S := struct.decl [
    "Addr" :: struct.t addr.Addr.S;
    "Blk" :: disk.blockT;
    "dirty" :: boolT
  ].
End Buf.

Definition MkBuf: val :=
  rec: "MkBuf" "addr" "blk" :=
    (if: slice.len "blk" > disk.BlockSize
    then
      Panic "mkbuf";;
      #()
    else #());;
    let: "b" := struct.new Buf.S [
      "Addr" ::= "addr";
      "Blk" ::= "blk";
      "dirty" ::= #false
    ] in
    "b".

(* Load the bits of a disk block into a new buf, as specified by addr *)
Definition MkBufLoad: val :=
  rec: "MkBufLoad" "addr" "blk" :=
    let: "bytefirst" := (struct.get addr.Addr.S "Off" "addr") `quot` #8 in
    let: "bytelast" := (struct.get addr.Addr.S "Off" "addr" + struct.get addr.Addr.S "Sz" "addr" - #1) `quot` #8 in
    let: "data" := SliceSubslice byteT "blk" "bytefirst" ("bytelast" + #1) in
    let: "b" := struct.new Buf.S [
      "Addr" ::= "addr";
      "Blk" ::= "data";
      "dirty" ::= #false
    ] in
    "b".

(* Install 1 bit from src into dst, at offset bit. return new dst. *)
Definition installOneBit: val :=
  rec: "installOneBit" "src" "dst" "bit" :=
    let: "new" := ref_to byteT "dst" in
    (if: ("src" & #(U8 1) ≪ "bit") ≠ ("dst" & #(U8 1) ≪ "bit")
    then
      (if: ("src" & #(U8 1) ≪ "bit") = #(U8 0)
      then "new" <-[byteT] (![byteT] "new" & ~ (#(U8 1) ≪ "bit"))
      else "new" <-[byteT] ![byteT] "new" ∥ #(U8 1) ≪ "bit");;
      #()
    else #());;
    ![byteT] "new".

(* Install bit from src to dst, at dstoff in destination. dstoff is in bits. *)
Definition installBit: val :=
  rec: "installBit" "src" "dst" "dstoff" :=
    let: "dstbyte" := "dstoff" `quot` #8 in
    SliceSet byteT "dst" "dstbyte" (installOneBit (SliceGet byteT "src" #0) (SliceGet byteT "dst" "dstbyte") ("dstoff" `rem` #8)).

(* Install bytes from src to dst. *)
Definition installBytes: val :=
  rec: "installBytes" "src" "dst" "dstoff" "nbit" :=
    let: "sz" := "nbit" `quot` #8 in
    SliceCopy byteT (SliceSkip byteT "dst" ("dstoff" `quot` #8)) (SliceTake "src" "sz").

(* Install the bits from buf into blk.  Two cases: a bit or an inode *)
Definition Buf__Install: val :=
  rec: "Buf__Install" "buf" "blk" :=
    util.DPrintf #1 (#(str"%v: install
    ")) (struct.loadF Buf.S "Addr" "buf");;
    (if: (struct.get addr.Addr.S "Sz" (struct.loadF Buf.S "Addr" "buf") = #1)
    then installBit (struct.loadF Buf.S "Blk" "buf") "blk" (struct.get addr.Addr.S "Off" (struct.loadF Buf.S "Addr" "buf"))
    else
      (if: ((struct.get addr.Addr.S "Sz" (struct.loadF Buf.S "Addr" "buf")) `rem` #8 = #0) && ((struct.get addr.Addr.S "Off" (struct.loadF Buf.S "Addr" "buf")) `rem` #8 = #0)
      then installBytes (struct.loadF Buf.S "Blk" "buf") "blk" (struct.get addr.Addr.S "Off" (struct.loadF Buf.S "Addr" "buf")) (struct.get addr.Addr.S "Sz" (struct.loadF Buf.S "Addr" "buf"))
      else
        Panic ("Install unsupported
        ")));;
    util.DPrintf #20 (#(str"install -> %v
    ")) "blk".

(* Load the bits of a disk block into buf, as specified by addr *)
Definition Buf__Load: val :=
  rec: "Buf__Load" "buf" "blk" :=
    let: "bytefirst" := (struct.get addr.Addr.S "Off" (struct.loadF Buf.S "Addr" "buf")) `quot` #8 in
    let: "bytelast" := (struct.get addr.Addr.S "Off" (struct.loadF Buf.S "Addr" "buf") + struct.get addr.Addr.S "Sz" (struct.loadF Buf.S "Addr" "buf") - #1) `quot` #8 in
    struct.storeF Buf.S "Blk" "buf" (SliceSubslice byteT "blk" "bytefirst" ("bytelast" + #1)).

Definition Buf__IsDirty: val :=
  rec: "Buf__IsDirty" "buf" :=
    struct.loadF Buf.S "dirty" "buf".

Definition Buf__SetDirty: val :=
  rec: "Buf__SetDirty" "buf" :=
    struct.storeF Buf.S "dirty" "buf" #true.

Definition Buf__WriteDirect: val :=
  rec: "Buf__WriteDirect" "buf" "d" :=
    Buf__SetDirty "buf";;
    (if: (struct.get addr.Addr.S "Sz" (struct.loadF Buf.S "Addr" "buf") = disk.BlockSize)
    then disk.Write (struct.get addr.Addr.S "Blkno" (struct.loadF Buf.S "Addr" "buf")) (struct.loadF Buf.S "Blk" "buf")
    else
      let: "blk" := disk.Read (struct.get addr.Addr.S "Blkno" (struct.loadF Buf.S "Addr" "buf")) in
      Buf__Install "buf" "blk";;
      disk.Write (struct.get addr.Addr.S "Blkno" (struct.loadF Buf.S "Addr" "buf")) "blk").

Definition Buf__BnumGet: val :=
  rec: "Buf__BnumGet" "buf" "off" :=
    let: "dec" := marshal.NewDec (SliceSubslice byteT (struct.loadF Buf.S "Blk" "buf") "off" ("off" + #8)) in
    marshal.Dec__GetInt "dec".

Definition Buf__BnumPut: val :=
  rec: "Buf__BnumPut" "buf" "off" "v" :=
    let: "enc" := marshal.NewEnc #8 in
    marshal.Enc__PutInt "enc" "v";;
    SliceCopy byteT (SliceSubslice byteT (struct.loadF Buf.S "Blk" "buf") "off" ("off" + #8)) (marshal.Enc__Finish "enc");;
    Buf__SetDirty "buf".

(* bufmap.go *)

Module BufMap.
  Definition S := struct.decl [
    "addrs" :: mapT (struct.ptrT Buf.S)
  ].
End BufMap.

Definition MkBufMap: val :=
  rec: "MkBufMap" <> :=
    let: "a" := struct.new BufMap.S [
      "addrs" ::= NewMap (struct.ptrT Buf.S)
    ] in
    "a".

Definition BufMap__Insert: val :=
  rec: "BufMap__Insert" "bmap" "buf" :=
    MapInsert (struct.loadF BufMap.S "addrs" "bmap") (addr.Addr__Flatid (struct.loadF Buf.S "Addr" "buf")) "buf".

Definition BufMap__Lookup: val :=
  rec: "BufMap__Lookup" "bmap" "addr" :=
    Fst (MapGet (struct.loadF BufMap.S "addrs" "bmap") (addr.Addr__Flatid "addr")).

Definition BufMap__Del: val :=
  rec: "BufMap__Del" "bmap" "addr" :=
    MapDelete (struct.loadF BufMap.S "addrs" "bmap") (addr.Addr__Flatid "addr").

Definition BufMap__Ndirty: val :=
  rec: "BufMap__Ndirty" "bmap" :=
    let: "n" := ref_to uint64T #0 in
    MapIter (struct.loadF BufMap.S "addrs" "bmap") (λ: <> "buf",
      (if: struct.loadF Buf.S "dirty" "buf"
      then "n" <-[uint64T] ![uint64T] "n" + #1
      else #()));;
    ![uint64T] "n".

Definition BufMap__DirtyBufs: val :=
  rec: "BufMap__DirtyBufs" "bmap" :=
    let: "bufs" := ref (zero_val (slice.T (refT (struct.t Buf.S)))) in
    MapIter (struct.loadF BufMap.S "addrs" "bmap") (λ: <> "buf",
      (if: struct.loadF Buf.S "dirty" "buf"
      then "bufs" <-[slice.T (refT (struct.t Buf.S))] SliceAppend (refT (struct.t Buf.S)) (![slice.T (refT (struct.t Buf.S))] "bufs") "buf"
      else #()));;
    ![slice.T (refT (struct.t Buf.S))] "bufs".
