requires "evm.md"
requires "foundry.md"

module CORK-LEMMAS
    imports EVM
    imports FOUNDRY
    imports INT-SYMBOLIC
    imports MAP-SYMBOLIC
    imports SET-SYMBOLIC

    syntax StepSort ::= Int
                      | Bool
                      | Bytes
                      | Map
                      | Set
 // -------------------------

    syntax KItem ::= runLemma ( StepSort )
                   | doneLemma( StepSort )
 // --------------------------------------
    rule <k> runLemma(T) => doneLemma(T) ... </k>

    //
    //  Arithmetic
    //
    rule C <=Int A *Int B => C /Int A <=Int B
      requires 0 <=Int C andBool 0 <Int A
       andBool C modInt A ==Int 0
       [simplification(40), concrete(C, A), preserves-definedness]

    rule A ==Int B => false
      requires 0 <=Int A andBool B <Int 0
      [simplification, concrete(B)]

    rule 0 <=Int A -Int B => B <=Int A
      [simplification, symbolic(A, B)]

    rule (A *Int (B *Int C)) => (A *Int B) *Int C
      [simplification, concrete(A, B)]

    rule (A *Int B) /Int C => ((A /Int 10) *Int B) /Int (C /Int 10)
      requires notBool (C ==Int 0) andBool A modInt 10 ==Int 0 andBool C modInt 10 ==Int 0
      [simplification, concrete(A, C), preserves-definedness]

    rule A /Int (B *Int C) => (A /Int 10) /Int ((B /Int 10) *Int C)
      requires notBool (B ==Int 0) andBool notBool (C ==Int 0)
       andBool A modInt 10 ==Int 0 andBool B modInt 10 ==Int 0
      [simplification, concrete(A, B), preserves-definedness]

    // Instantiation of the Kontrol lemma
    // rule ( X ==Int ( X *Int Y ) /Word Y ) orBool Y ==Int 0 => true [simplification, preserves-definedness]
    // when Y is of the form Y *Int Z, because then the `Y ==Int 0` condition gets simplified to a different form
    rule ( X ==Int ( X *Int (Y *Int Z) ) /Word (Y *Int Z) ) orBool (Y ==Int 0 orBool Z ==Int 0) => true [simplification, preserves-definedness]

    // Instantiation of the Kontrol lemma
    // rule ( X ==Int ( X *Int Y ) /Word Y ) orBool Y ==Int 0 => true [simplification, preserves-definedness]
    // when Y is of the form Y *Int ( Z *Int T ), because then the `Y ==Int 0` condition gets simplified to a different form
    rule ( X ==Int ( X *Int (Y *Int (Z *Int T)) ) /Word (Y *Int (Z *Int T)) ) orBool (Y ==Int 0 orBool (Z ==Int 0 orBool T ==Int 0)) => true [simplification, preserves-definedness]

    // Instantiation of the Kontrol lemma
    // rule ( X ==Int ( X *Int Y ) /Word Y ) orBool Y ==Int 0 => true [simplification, preserves-definedness]
    // when Y is of the form Y /Int Z, because then the `Y ==Int 0` condition gets simplified to a different form
    rule ( X ==Int ( X *Int (Y /Int Z) ) /Word (Y /Int Z) ) orBool Y <Int Z => true
      requires notBool ( Z ==Int 0 )
      [simplification, preserves-definedness]

    rule [chop-sub]:
      chop ( Y -Int X:Int ) ==Int 0 => X ==Int Y
      requires #rangeUInt(256, X) andBool #rangeUInt(256, Y)
      [simplification, concrete(Y), comm]

    rule [keccak-slots-disjoint]:
      keccak ( A ) ==Int keccak ( B ) +Int C => false
      requires notBool 0 ==Int C
      [simplification, concrete(C), comm]

    rule [keccak-slots-disjoint-ml-l]:
      { keccak ( A ) #Equals keccak ( B ) +Int C } => #Bottom
      requires notBool 0 ==Int C
      [simplification, concrete(C)]

    rule [keccak-slots-disjoint-ml-r]:
      { keccak ( B ) +Int C #Equals keccak ( A ) } => #Bottom
      requires notBool 0 ==Int C
      [simplification, concrete(C)]

    rule ( SetItem(X:Int) S:Set ) |Set SetItem(Y:Int) => SetItem(X) ( S |Set SetItem (Y) ) requires notBool X ==Int Y [simplification, preserves-definedness]
    rule ( SetItem(X:Int) S:Set ) |Set SetItem(Y:Int) => SetItem(X) S                      requires         X ==Int Y [simplification, preserves-definedness]
    rule                     .Set |Set SetItem(X:Int) => SetItem(X)                                                   [simplification, preserves-definedness]

    rule K1 in_keys((K2 |-> _ ) M) => K1 ==Int K2 orBool K1 in_keys(M) [simplification]

    rule [transferFunds-hp-neq]:
      <k> #transferFunds ACCTFROM ACCTTO VALUE => .K ... </k>
      <account>
        <acctID> ACCTFROM </acctID>
        <balance> ORIGFROM => ORIGFROM -Word VALUE </balance>
        ...
      </account>
      <account>
        <acctID> ACCTTO </acctID>
        <balance> ORIGTO => ORIGTO +Word VALUE </balance>
        ...
      </account>
      requires ACCTFROM =/=K ACCTTO andBool VALUE <=Int ORIGFROM
      [priority(30), preserves-definedness]

    rule [accounts-in-keys]:
      `AccountCellMap:in_keys`(
        <acctID> (X:Int) </acctID>,
        (`_AccountCellMap_`(AccountCellMapItem(<acctID> Y:Int </acctID>, _:AccountCell):AccountCellMap, ACCOUNTS_REST:AccountCellMap)):AccountCellMap
      ) => X ==Int Y orBool `AccountCellMap:in_keys`(<acctID> (X:Int) </acctID>, ACCOUNTS_REST)
      [simplification, preserves-definedness]

endmodule

module CORK-LEMMAS-SPEC
    imports CORK-LEMMAS

endmodule