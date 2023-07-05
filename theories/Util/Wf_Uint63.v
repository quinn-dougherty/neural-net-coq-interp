From Coq Require Import Bool Uint63 ZArith Wellfounded Wf_Z Wf_nat Lia.
From NeuralNetInterp.Util Require Import Monad.
Set Universe Polymorphism.
Set Polymorphic Inductive Cumulativity.
Unset Universe Minimization ToSet.
Local Open Scope uint63_scope.

#[local] Coercion Uint63.to_Z : int >-> Z.
#[local] Coercion Z.to_nat : Z >-> nat.
#[local] Coercion is_true : bool >-> Sortclass.
Definition ltof {A} (f : A -> int) (a b : A) := f a <? f b.

Lemma well_founded_ltof {A f} : well_founded (@ltof A f).
Proof.
  unshelve eapply well_founded_lt_compat with (fun x:A => f x:nat); cbv [is_true ltof].
  intros *; rewrite Uint63.ltb_spec, Z2Nat.inj_lt by apply to_Z_bounded; trivial.
Qed.

Lemma lt_wf : well_founded ltb.
Proof.
  apply @well_founded_ltof with (f:=fun x => x).
Qed.

Lemma well_founded_gtof {A f} {bound} : well_founded (fun x y:A => (f y <? f x) && (f x <=? bound)).
Proof.
  apply @well_founded_lt_compat with (f:=fun x:A => bound - f x); cbv [is_true ltof].
  intros x y.
  pose proof (to_Z_bounded (f y)).
  pose proof (to_Z_bounded (f x)).
  pose proof (to_Z_bounded bound).
  rewrite andb_true_iff, Uint63.ltb_spec, Uint63.leb_spec, !Uint63.sub_spec by apply to_Z_bounded.
  intros; rewrite !Z.mod_small by lia; lia.
Qed.

Lemma gt_wf {bound} : well_founded (fun x y => (y <? x) && (x <=? bound)).
Proof.
  apply @well_founded_gtof with (f:=fun x => x).
Qed.

#[global] Arguments gt_wf {_}, _.

Inductive LoopBody_ S A : Type :=
| break (v : S) : LoopBody_ S A
| continue (v : S) : LoopBody_ S A
| ret (v : A) (st : S) : LoopBody_ S A
.
#[global] Arguments break {_ _}.
#[global] Arguments continue {_ _}.
#[global] Arguments ret {_ _}.

Definition LoopBody S A := S -> LoopBody_ S A.
Definition bind {S A B} (x : LoopBody S A) (k : A -> LoopBody S B) : LoopBody S B
  := fun st => match x st with
               | break st => break st
               | continue st => continue st
               | ret x st => k x st
               end.
Definition get {S} : LoopBody S S := fun st => ret st st.
Definition update {S} (v : S -> S) : LoopBody S unit := fun st => ret tt (v st).
Definition set {S} (v : S) : LoopBody S unit := update (fun _ => v).
#[export] Instance LoopBody_Monad {S} : Monad (LoopBody S) := { ret := @ret S ; bind := @bind S }.

Definition run_body {S}
  (v : LoopBody S unit)
  {T}
  (breakf : S -> T) (continuef : S -> T)
  (st : S)
  : T
  := match v st with
     | break v => breakf v
     | continue v => continuef v
     | ret tt v => continuef v
     end.

Definition for_loop_lt {A} (i : int) (max : int) (step : int)
  (body : int -> LoopBody A unit)
  (init : A)
  : A.
Proof.
  refine (let step := if (step =? 0) then 1 else step in
          Fix
            (Acc_intro_generator Uint63.size (@gt_wf max))
            (fun _ => _)
            (fun i continue state
             => if Sumbool.sumbool_of_bool (i <? max)
                then
                  let break := fun v => v in
                  let continue := if Sumbool.sumbool_of_bool (step <? (max - i))
                                  then (fun v => continue (i + step) _ v)
                                  else (fun v => v) in
                  run_body (body i) break continue state
                else state)
            i
            init).
  { abstract
      (cbv [is_true];
       pose proof (Uint63.to_Z_bounded max);
       pose proof (Uint63.to_Z_bounded i);
       pose proof (Uint63.to_Z_bounded step);
       assert (0 < Uint63.to_Z step)%Z
         by (repeat match goal with H : context[step] |- _ => revert H end;
             subst step;
             case Uint63.eqbP; rewrite Uint63.to_Z_0, ?Uint63.to_Z_1; intros; lia);
       rewrite andb_true_iff;
       rewrite Uint63.ltb_spec, Uint63.leb_spec, Uint63.sub_spec, Uint63.add_spec in *;
       rewrite !Z.mod_small in * by lia;
       lia). }
Defined.

Module LoopNotation.
  Export MonadNotation.
  Notation break := break.
  Notation continue := continue.
  Notation get := get.
  Notation update := update.
  Notation set := set.
  Notation ret := Monad.ret (only parsing).
  Notation bind := Monad.bind (only parsing).
  #[export] Existing Instance LoopBody_Monad.

  Notation "'with_state' state 'for' ( x := init ;; x <? max ;; x += step ) {{ body }}"
    := (for_loop_lt init max step (fun x => body%monad) state)
         (x binder, init at level 49, max at level 49, step at level 49, body at level 200, only printing, format "'with_state'  '/' '[hv ' state ']'  '//' 'for'  ( x  :=  init ;;  x  <?  max ;;  x  +=  step ) '//' '[v  ' {{  '/' body ']' '//' }}").
  Notation "'with_state' state 'for' ( x := init ;; x <? max ;; x ++ ) {{ body }}"
    := (for_loop_lt init max 1 (fun x => body%monad) state)
         (x binder, init at level 49, max at level 49, body at level 200, only printing, format "'with_state'  '/' '[hv ' state ']'  '//' 'for'  ( x  :=  init ;;  x  <?  max ;;  x ++ )  '//' '[v  ' {{  '//' body ']' '//' }}").
  Notation "'with_state' state 'for' ( x := init ;; y <? max ;; z += step ) {{ body }}"
    := (match (fun x : unit => conj (eq_refl : x = y) (eq_refl : x = z)) return _ with
        | _
          => for_loop_lt init max step (fun x => body%monad) state
        end)
         (only parsing, x binder, init at level 49, max at level 49, step at level 49, y at level 49, z at level 49, body at level 200).
  Notation "'with_state' state 'for' ( x := init ;; y <? max ;; z ++ ) {{ body }}"
    := (match (fun x : unit => conj (eq_refl : x = y) (eq_refl : x = z)) return _ with
        | _
          => for_loop_lt init max 1 (fun x => body%monad) state
        end)
         (only parsing, x binder, init at level 49, max at level 49, y at level 49, z at level 49, body at level 200).
  (*
  Check with_state 0 for (x := 0;; x <? 10;; x++) {{ y <- get;; set (y+x) }}.
   *)
End LoopNotation.
