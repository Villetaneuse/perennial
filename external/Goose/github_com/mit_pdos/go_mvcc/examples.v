(* autogenerated from github.com/mit-pdos/go-mvcc/examples *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.go_mvcc.txn.

From Perennial.goose_lang Require Import ffi.grove_prelude.

(* counter.go *)

Definition fetch: val :=
  rec: "fetch" "txn" "p" :=
    let: ("v", <>) := txn.Txn__Get "txn" #0 in
    "p" <-[uint64T] "v";;
    #true.

Definition Fetch: val :=
  rec: "Fetch" "t" :=
    let: "n" := ref (zero_val uint64T) in
    let: "body" := (λ: "txn",
      fetch "txn" "n"
      ) in
    txn.Txn__DoTxn "t" "body";;
    ![uint64T] "n".

Definition increment: val :=
  rec: "increment" "txn" "p" :=
    let: ("v", <>) := txn.Txn__Get "txn" #0 in
    "p" <-[uint64T] "v";;
    (if: ("v" = #18446744073709551615)
    then #false
    else
      txn.Txn__Put "txn" #0 ("v" + #1);;
      #true).

Definition Increment: val :=
  rec: "Increment" "t" :=
    let: "n" := ref (zero_val uint64T) in
    let: "body" := (λ: "txn",
      increment "txn" "n"
      ) in
    let: "ok" := txn.Txn__DoTxn "t" "body" in
    (![uint64T] "n", "ok").

Definition decrement: val :=
  rec: "decrement" "txn" "p" :=
    let: ("v", <>) := txn.Txn__Get "txn" #0 in
    "p" <-[uint64T] "v";;
    (if: ("v" = #0)
    then #false
    else
      txn.Txn__Put "txn" #0 ("v" - #1);;
      #true).

Definition Decrement: val :=
  rec: "Decrement" "t" :=
    let: "n" := ref (zero_val uint64T) in
    let: "body" := (λ: "txn",
      decrement "txn" "n"
      ) in
    let: "ok" := txn.Txn__DoTxn "t" "body" in
    (![uint64T] "n", "ok").

Definition InitializeCounterData: val :=
  rec: "InitializeCounterData" "mgr" :=
    let: "body" := (λ: "txn",
      txn.Txn__Put "txn" #0 #0;;
      #true
      ) in
    let: "t" := txn.TxnMgr__New "mgr" in
    Skip;;
    (for: (λ: <>, ~ (txn.Txn__DoTxn "t" "body")); (λ: <>, Skip) := λ: <>,
      Continue);;
    #().

Definition InitCounter: val :=
  rec: "InitCounter" <> :=
    let: "mgr" := txn.MkTxnMgr #() in
    InitializeCounterData "mgr";;
    "mgr".

Definition CallIncrement: val :=
  rec: "CallIncrement" "mgr" :=
    let: "txn" := txn.TxnMgr__New "mgr" in
    Increment "txn";;
    #().

Definition CallIncrementFetch: val :=
  rec: "CallIncrementFetch" "mgr" :=
    let: "txn" := txn.TxnMgr__New "mgr" in
    let: ("n1", "ok1") := Increment "txn" in
    (if: ~ "ok1"
    then #()
    else
      let: "n2" := Fetch "txn" in
      control.impl.Assert ("n1" < "n2");;
      #()).

Definition CallDecrement: val :=
  rec: "CallDecrement" "mgr" :=
    let: "txn" := txn.TxnMgr__New "mgr" in
    Decrement "txn";;
    #().

(* rsvkey.go *)

Definition WriteReservedKeySeq: val :=
  rec: "WriteReservedKeySeq" "txn" "v" :=
    txn.Txn__Put "txn" #0 "v";;
    #true.

Definition WriteReservedKey: val :=
  rec: "WriteReservedKey" "t" "v" :=
    let: "body" := (λ: "txn",
      WriteReservedKeySeq "txn" "v"
      ) in
    txn.Txn__DoTxn "t" "body".

Definition WriteFreeKeySeq: val :=
  rec: "WriteFreeKeySeq" "txn" "v" :=
    txn.Txn__Put "txn" #1 "v";;
    #true.

Definition WriteFreeKey: val :=
  rec: "WriteFreeKey" "t" "v" :=
    let: "body" := (λ: "txn",
      WriteFreeKeySeq "txn" "v"
      ) in
    txn.Txn__DoTxn "t" "body".

Definition InitializeData: val :=
  rec: "InitializeData" "mgr" :=
    #().

Definition InitExample: val :=
  rec: "InitExample" <> :=
    let: "mgr" := txn.MkTxnMgr #() in
    InitializeData "mgr";;
    "mgr".

Definition WriteReservedKeyExample: val :=
  rec: "WriteReservedKeyExample" "mgr" "v" :=
    let: "txn" := txn.TxnMgr__New "mgr" in
    let: "ok" := WriteReservedKey "txn" "v" in
    "ok".

Definition WriteFreeKeyExample: val :=
  rec: "WriteFreeKeyExample" "mgr" "v" :=
    let: "txn" := txn.TxnMgr__New "mgr" in
    let: "ok" := WriteFreeKey "txn" "v" in
    "ok".
