(* autogenerated from github.com/mit-pdos/go-mvcc/tuple *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.go_mvcc.common.

Section code.
Context `{ext_ty: ext_types}.
Local Coercion Var' s: expr := Var s.

(* *
    * The lifetime of a version starts from `begin` of itself to the `begin` of
    * next version; it's a half-open interval (]. *)
Definition Version := struct.decl [
  "begin" :: uint64T;
  "deleted" :: boolT;
  "val" :: stringT
].

(* *
    * `owned`: A boolean flag indicating whether some txn owns this tuple..
    *
    * `tidlast`:
    * 	An TID specifying the last txn (in the sense of the largest TID, not actual
    * 	physical time) that reads (TID) or writes (TID + 1) this tuple.
    *
    * `vers`: Physical versions. *)
Definition Tuple := struct.decl [
  "latch" :: ptrT;
  "rcond" :: ptrT;
  "owned" :: boolT;
  "tidlast" :: uint64T;
  "vers" :: slice.T (struct.t Version)
].

Definition findRightVer: val :=
  rec: "findRightVer" "tid" "vers" :=
    let: "ver" := ref (zero_val (struct.t Version)) in
    let: "length" := slice.len "vers" in
    let: "idx" := ref_to uint64T #0 in
    Skip;;
    (for: (λ: <>, ![uint64T] "idx" < "length"); (λ: <>, Skip) := λ: <>,
      "ver" <-[struct.t Version] SliceGet (struct.t Version) "vers" ("length" - ![uint64T] "idx" - #1);;
      (if: "tid" > struct.get Version "begin" (![struct.t Version] "ver")
      then Break
      else
        "idx" <-[uint64T] ![uint64T] "idx" + #1;;
        Continue));;
    ![struct.t Version] "ver".

(* *
    * Preconditions:
    *
    * Postconditions:
    * 1. On a successful return, the txn `tid` get the permission to update this
    * tuple (when we also acquire the latch of this tuple). *)
Definition Tuple__Own: val :=
  rec: "Tuple__Own" "tuple" "tid" :=
    lock.acquire (struct.loadF Tuple "latch" "tuple");;
    (if: "tid" < struct.loadF Tuple "tidlast" "tuple"
    then
      lock.release (struct.loadF Tuple "latch" "tuple");;
      common.RET_UNSERIALIZABLE
    else
      (if: struct.loadF Tuple "owned" "tuple"
      then
        lock.release (struct.loadF Tuple "latch" "tuple");;
        common.RET_RETRY
      else
        struct.storeF Tuple "owned" "tuple" #true;;
        lock.release (struct.loadF Tuple "latch" "tuple");;
        common.RET_SUCCESS)).

Definition Tuple__WriteLock: val :=
  rec: "Tuple__WriteLock" "tuple" :=
    lock.acquire (struct.loadF Tuple "latch" "tuple");;
    #().

Definition Tuple__appendVersion: val :=
  rec: "Tuple__appendVersion" "tuple" "tid" "val" :=
    let: "verNew" := struct.mk Version [
      "begin" ::= "tid";
      "val" ::= "val";
      "deleted" ::= #false
    ] in
    struct.storeF Tuple "vers" "tuple" (SliceAppend (struct.t Version) (struct.loadF Tuple "vers" "tuple") "verNew");;
    struct.storeF Tuple "owned" "tuple" #false;;
    struct.storeF Tuple "tidlast" "tuple" ("tid" + #1);;
    #().

(* *
    * Preconditions:
    * 1. The txn `tid` has the permission to update this tuple. *)
Definition Tuple__AppendVersion: val :=
  rec: "Tuple__AppendVersion" "tuple" "tid" "val" :=
    Tuple__appendVersion "tuple" "tid" "val";;
    lock.condBroadcast (struct.loadF Tuple "rcond" "tuple");;
    lock.release (struct.loadF Tuple "latch" "tuple");;
    #().

Definition Tuple__killVersion: val :=
  rec: "Tuple__killVersion" "tuple" "tid" :=
    let: "verNew" := struct.mk Version [
      "begin" ::= "tid";
      "deleted" ::= #true
    ] in
    struct.storeF Tuple "vers" "tuple" (SliceAppend (struct.t Version) (struct.loadF Tuple "vers" "tuple") "verNew");;
    struct.storeF Tuple "owned" "tuple" #false;;
    struct.storeF Tuple "tidlast" "tuple" ("tid" + #1);;
    #true.

(* *
    * Preconditions:
    * 1. The txn `tid` has the permission to update this tuple. *)
Definition Tuple__KillVersion: val :=
  rec: "Tuple__KillVersion" "tuple" "tid" :=
    let: "ok" := Tuple__killVersion "tuple" "tid" in
    let: "ret" := ref (zero_val uint64T) in
    (if: "ok"
    then "ret" <-[uint64T] common.RET_SUCCESS
    else "ret" <-[uint64T] common.RET_NONEXIST);;
    lock.condBroadcast (struct.loadF Tuple "rcond" "tuple");;
    lock.release (struct.loadF Tuple "latch" "tuple");;
    ![uint64T] "ret".

(* *
    * Preconditions: *)
Definition Tuple__Free: val :=
  rec: "Tuple__Free" "tuple" :=
    lock.acquire (struct.loadF Tuple "latch" "tuple");;
    struct.storeF Tuple "owned" "tuple" #false;;
    lock.condBroadcast (struct.loadF Tuple "rcond" "tuple");;
    lock.release (struct.loadF Tuple "latch" "tuple");;
    #().

Definition Tuple__ReadWait: val :=
  rec: "Tuple__ReadWait" "tuple" "tid" :=
    lock.acquire (struct.loadF Tuple "latch" "tuple");;
    Skip;;
    (for: (λ: <>, ("tid" > struct.loadF Tuple "tidlast" "tuple") && (struct.loadF Tuple "owned" "tuple")); (λ: <>, Skip) := λ: <>,
      lock.condWait (struct.loadF Tuple "rcond" "tuple");;
      Continue);;
    #().

(* *
    * Preconditions: *)
Definition Tuple__ReadVersion: val :=
  rec: "Tuple__ReadVersion" "tuple" "tid" :=
    let: "ver" := findRightVer "tid" (struct.loadF Tuple "vers" "tuple") in
    (if: struct.loadF Tuple "tidlast" "tuple" < "tid"
    then struct.storeF Tuple "tidlast" "tuple" "tid"
    else #());;
    lock.release (struct.loadF Tuple "latch" "tuple");;
    (struct.get Version "val" "ver", ~ (struct.get Version "deleted" "ver")).

Definition Tuple__removeVersions: val :=
  rec: "Tuple__removeVersions" "tuple" "tid" :=
    let: "idx" := ref (zero_val uint64T) in
    "idx" <-[uint64T] slice.len (struct.loadF Tuple "vers" "tuple") - #1;;
    Skip;;
    (for: (λ: <>, ![uint64T] "idx" ≠ #0); (λ: <>, Skip) := λ: <>,
      let: "ver" := SliceGet (struct.t Version) (struct.loadF Tuple "vers" "tuple") (![uint64T] "idx") in
      (if: struct.get Version "begin" "ver" < "tid"
      then Break
      else
        "idx" <-[uint64T] ![uint64T] "idx" - #1;;
        Continue));;
    struct.storeF Tuple "vers" "tuple" (SliceSkip (struct.t Version) (struct.loadF Tuple "vers" "tuple") (![uint64T] "idx"));;
    #().

(* *
    * Remove all versions whose `end` timestamp is less than or equal to `tid`.
    * Preconditions: *)
Definition Tuple__RemoveVersions: val :=
  rec: "Tuple__RemoveVersions" "tuple" "tid" :=
    lock.acquire (struct.loadF Tuple "latch" "tuple");;
    Tuple__removeVersions "tuple" "tid";;
    lock.release (struct.loadF Tuple "latch" "tuple");;
    #().

Definition MkTuple: val :=
  rec: "MkTuple" <> :=
    let: "tuple" := struct.alloc Tuple (zero_val (struct.t Tuple)) in
    struct.storeF Tuple "latch" "tuple" (lock.new #());;
    struct.storeF Tuple "rcond" "tuple" (lock.newCond (struct.loadF Tuple "latch" "tuple"));;
    struct.storeF Tuple "owned" "tuple" #false;;
    struct.storeF Tuple "tidlast" "tuple" #1;;
    struct.storeF Tuple "vers" "tuple" (NewSliceWithCap (struct.t Version) #1 #16);;
    SliceSet (struct.t Version) (struct.loadF Tuple "vers" "tuple") #0 (struct.mk Version [
      "deleted" ::= #true
    ]);;
    "tuple".

End code.
