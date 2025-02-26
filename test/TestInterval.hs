{-# LANGUAGE CPP, TemplateHaskell, RankNTypes, ScopedTypeVariables #-}
module TestInterval (intervalTestGroup) where

#ifdef MIN_VERSION_lattices
import qualified Algebra.Lattice as L
#endif
import Control.DeepSeq
import Control.Exception
import Control.Monad
import Data.Generics.Schemes
import Data.Hashable
import Data.Int
import Data.Maybe
import Data.Ratio
import Data.Typeable

import Test.Tasty
import Test.Tasty.QuickCheck
import Test.Tasty.HUnit
import Test.Tasty.Options
import Test.Tasty.TH
#ifdef MIN_VERSION_quickcheck_classes_base
import Test.QuickCheck.Classes.Base
#endif

import Data.Interval
  ( Interval, Extended (..), (<=..<=), (<=..<), (<..<=), (<..<)
  , (<!), (<=!), (==!), (>=!), (>!), (/=!)
  , (<?), (<=?), (==?), (>=?), (>?), (/=?)
  , (<??), (<=??), (==??), (>=??), (>??), (/=??)
  )
import qualified Data.Interval as Interval
import Data.IntervalRelation

import TestInstances

{--------------------------------------------------------------------
  empty
--------------------------------------------------------------------}

prop_empty_is_bottom =
  forAll intervals $ \a ->
    Interval.isSubsetOf Interval.empty a

prop_null_empty =
  forAll intervals $ \a ->
    Interval.null a == (a == Interval.empty)

case_null_empty =
  Interval.null (Interval.empty :: Interval Rational) @?= True

{--------------------------------------------------------------------
  whole
--------------------------------------------------------------------}

prop_whole_is_top =
  forAll intervals $ \a ->
    Interval.isSubsetOf a Interval.whole

case_nonnull_top =
  Interval.null (Interval.whole :: Interval Rational) @?= False

{--------------------------------------------------------------------
  singleton
--------------------------------------------------------------------}

-- prop_singleton_isSingleton =
--   forAll arbitrary $ \(r::Rational) ->
--     Interval.isSingleton (Interval.singleton r)

prop_singleton_member =
  forAll arbitrary $ \r ->
    Interval.member (r::Rational) (Interval.singleton r)

prop_singleton_member_intersection =
  forAll intervals $ \a ->
  forAll arbitrary $ \r ->
    let b = Interval.singleton r
    in Interval.member (r::Rational) a
       ==> Interval.intersection a b == b

prop_singleton_nonnull =
  forAll arbitrary $ \r1 ->
    not $ Interval.null $ Interval.singleton (r1::Rational)

prop_distinct_singleton_intersection =
  forAll arbitrary $ \r1 ->
  forAll arbitrary $ \r2 ->
    (r1::Rational) /= r2 ==>
      Interval.intersection (Interval.singleton r1) (Interval.singleton r2)
      == Interval.empty

{--------------------------------------------------------------------
  Intersection
--------------------------------------------------------------------}

prop_intersection_comm =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.intersection a b == Interval.intersection b a

prop_intersection_assoc =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    Interval.intersection a (Interval.intersection b c) ==
    Interval.intersection (Interval.intersection a b) c

prop_intersection_unitL =
  forAll intervals $ \a ->
    Interval.intersection Interval.whole a == a

prop_intersection_unitR =
  forAll intervals $ \a ->
    Interval.intersection a Interval.whole == a

prop_intersection_empty =
  forAll intervals $ \a ->
    Interval.intersection a Interval.empty == Interval.empty

prop_intersection_isSubsetOf =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.isSubsetOf (Interval.intersection a b) a

prop_intersection_isSubsetOf_equiv =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    (Interval.intersection a b == a)
    == Interval.isSubsetOf a b

case_intersections_empty_list = Interval.intersections [] @?= (Interval.whole :: Interval Rational)

prop_intersections_singleton_list =
  forAll intervals $ \a -> Interval.intersections [a] == a

prop_intersections_two_elems =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.intersections [a,b] == Interval.intersection a b

{--------------------------------------------------------------------
  Hull
--------------------------------------------------------------------}

prop_hull_comm =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.hull a b == Interval.hull b a

prop_hull_assoc =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    Interval.hull a (Interval.hull b c) ==
    Interval.hull (Interval.hull a b) c

prop_hull_unitL =
  forAll intervals $ \a ->
    Interval.hull Interval.empty a == a

prop_hull_unitR =
  forAll intervals $ \a ->
    Interval.hull a Interval.empty == a

prop_hull_whole =
  forAll intervals $ \a ->
    Interval.hull a Interval.whole == Interval.whole

prop_hull_isSubsetOf =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.isSubsetOf a (Interval.hull a b)

prop_hull_isSubsetOf_equiv =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    (Interval.hull a b == b)
    == Interval.isSubsetOf a b

case_hulls_empty_list = Interval.hulls [] @?= (Interval.empty :: Interval Rational)

prop_hulls_singleton_list =
  forAll intervals $ \a -> Interval.hulls [a] == a

prop_hulls_two_elems =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    Interval.hulls [a,b] == Interval.hull a b

{--------------------------------------------------------------------
  member
--------------------------------------------------------------------}

prop_member_isSubsetOf =
  forAll arbitrary $ \r ->
  forAll intervals $ \a ->
    Interval.member r a == Interval.isSubsetOf (Interval.singleton r) a

prop_notMember_empty =
  forAll arbitrary $ \(r::Rational) ->
    r `Interval.notMember` Interval.empty

{--------------------------------------------------------------------
  isSubsetOf
--------------------------------------------------------------------}

prop_isSubsetOf_refl =
  forAll intervals $ \a ->
    Interval.isSubsetOf a a

test_isSubsetOf_trans :: [TestTree]
test_isSubsetOf_trans =
  (: []) $
  adjustOption (\(QuickCheckMaxRatio r) -> QuickCheckMaxRatio (r * 10)) $
  testProperty "isSubsetOf trans" $
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    Interval.isSubsetOf a b && Interval.isSubsetOf b c
    ==> Interval.isSubsetOf a c

-- prop_isSubsetOf_antisym =
--   forAll intervals $ \a ->
--   forAll intervals $ \b ->
--     Interval.isSubsetOf a b && Interval.isSubsetOf b a
--     ==> a == b

prop_isProperSubsetOf_not_refl =
  forAll intervals $ \a ->
    not (a `Interval.isProperSubsetOf` a)

-- too slow
-- prop_isProperSubsetOf_trans =
--   forAll intervals $ \a ->
--   forAll (liftM (Interval.intersection a) intervals) $ \b ->
--   forAll (liftM (Interval.intersection b) intervals) $ \c ->
--     Interval.isProperSubsetOf c b && Interval.isProperSubsetOf b a
--     ==> Interval.isProperSubsetOf c a

case_isProperSubsetOf =
  (0 <=..<= 1) `Interval.isProperSubsetOf` (0 <=..<= 2) @?= True

{-- -----------------------------------------------------------------
  isConnected
----------------------------------------------------------------- --}

prop_isConnected_reflexive =
  forAll intervals $ \a ->
    a `Interval.isConnected` a

prop_isConnected_symmetric =
  forAll intervals $ \a ->
    forAll intervals $ \b ->
      (a `Interval.isConnected` b) == (b `Interval.isConnected` a)

{--------------------------------------------------------------------
  simplestRationalWithin
--------------------------------------------------------------------}

prop_simplestRationalWithin_member =
  forAll intervals $ \a ->
    case Interval.simplestRationalWithin a of
      Nothing -> True
      Just x -> x `Interval.member` a

prop_simplestRationalWithin_and_approxRational =
  forAll arbitrary $ \(r::Rational) ->
    forAll arbitrary $ \(eps::Rational) ->
      eps > 0 ==> Interval.simplestRationalWithin (Finite (r-eps) <=..<= Finite (r+eps)) == Just (approxRational r eps)

prop_simplestRationalWithin_singleton =
  forAll arbitrary $ \(r::Rational) ->
      Interval.simplestRationalWithin (Interval.singleton r) == Just r

case_simplestRationalWithin_empty =
  Interval.simplestRationalWithin Interval.empty @?= Nothing

case_simplestRationalWithin_test1 =
  Interval.simplestRationalWithin (Finite (-0.5 :: Rational) <=..<= 0.5) @?= Just 0

case_simplestRationalWithin_test2 =
  Interval.simplestRationalWithin (Finite (2 :: Rational) <..< 3) @?= Just 2.5

case_simplestRationalWithin_test2' =
  Interval.simplestRationalWithin (Finite (-3 :: Rational) <..< (-2)) @?= Just (-2.5)

case_simplestRationalWithin_test3 =
  Interval.simplestRationalWithin (Finite (1.4142135623730951 :: Rational) <..< Finite 1.7320508075688772) @?= Just 1.5

-- http://en.wikipedia.org/wiki/Best_rational_approximation#Best_rational_approximations
case_simplestRationalWithin_test4 =
  Interval.simplestRationalWithin (Finite (3.14155 :: Rational) <..< Finite 3.14165) @?= Just (355/113)

case_simplestRationalWithin_test5 =
  Interval.simplestRationalWithin (Finite (1.1e-20 :: Rational) <..< Finite (1.2e-20)) @?= Just (1/83333333333333333334)

{--------------------------------------------------------------------
  pickup
--------------------------------------------------------------------}

prop_pickup_member_null =
  forAll intervals $ \a ->
    case Interval.pickup a of
      Nothing -> Interval.null a
      Just x -> Interval.member x a

case_pickup_empty =
  Interval.pickup (Interval.empty :: Interval Rational) @?= Nothing

case_pickup_whole =
  isJust (Interval.pickup (Interval.whole :: Interval Rational)) @?= True

prop_pickup_singleton =
  forAll arbitrary $ \(x::Rational) ->
    Interval.pickup (Interval.singleton x) == Just x

{--------------------------------------------------------------------
  width
--------------------------------------------------------------------}

case_width_null =
  Interval.width Interval.empty @?= 0

prop_width_singleton =
  forAll arbitrary $ \(r::Rational) ->
    Interval.width (Interval.singleton r) == 0

{--------------------------------------------------------------------
  map
--------------------------------------------------------------------}

case_mapMonotonic =
  Interval.mapMonotonic (+1) (0 <=..< 10) @?= ((1 <=..<11) :: Interval Rational)

{--------------------------------------------------------------------
  relate
--------------------------------------------------------------------}

prop_relate_equals =
  forAll intervals $ \a ->
    Interval.relate a a == Equal

prop_relate_empty_contained_in_non_empty =
  forAll (intervals `suchThat` (not . Interval.null)) $ \a ->
    Interval.relate a Interval.empty == Contains

prop_relate_detects_before =
  forAll (nonEmptyIntervalPairs (\_ (ub1, _) (lb2, _) _ -> ub1 < lb2)) $ \(a, b) ->
    Interval.relate a b == Before

prop_relate_open_intervals_with_common_boundary_are_before =
  forAll (arbitrary `suchThat` \(b1, b2, i) -> fst b1 < i && i < fst b2) $
      \(b1 :: (Extended Rational, Interval.Boundary), b2, i :: Extended Rational) ->
        Interval.relate (Interval.interval b1 (i, Interval.Open)) (Interval.interval (i, Interval.Open) b2) == Before

prop_relate_right_closed_interval_just_before =
  forAll (arbitrary `suchThat` \(b1, b2, i) -> fst b1 < i && i < fst b2) $
      \(b1 :: (Extended Rational, Interval.Boundary), b2, i :: Extended Rational) ->
        Interval.relate (Interval.interval b1 (i, Interval.Closed)) (Interval.interval (i, Interval.Open) b2) == JustBefore

prop_relate_right_open_interval_just_before =
  forAll (arbitrary `suchThat` \(b1, b2, i) -> fst b1 < i && i < fst b2) $
      \(b1 :: (Extended Rational, Interval.Boundary), b2, i :: Extended Rational) ->
        Interval.relate (Interval.interval b1 (i, Interval.Open)) (Interval.interval (i, Interval.Closed) b2) == JustBefore

prop_relate_two_intervals_overlap =
  forAll (nonEmptyIntervalPairs (\(lb1, _) (ub1, _) (lb2, _) (ub2, _) -> lb1 < lb2 && lb2 < ub1 && ub1 < ub2)) $ \(a, b) ->
    Interval.relate a b == Overlaps

prop_relate_interval_starts_another =
  forAll (nonEmptyIntervalPairs (\lb1 (ub1, _) lb2 (ub2, _) -> lb1 == lb2 && ub1 < ub2)) $ \(a, b) ->
    Interval.relate a b == Starts

prop_relate_interval_finishes_another =
  forAll (nonEmptyIntervalPairs (\(lb1, _) ub1 (lb2, _) ub2 -> lb1 > lb2 && ub1 == ub2)) $ \(a, b) ->
    Interval.relate a b == Finishes

prop_relate_interval_contains_another =
  forAll (nonEmptyIntervalPairs (\(lb1, _) (ub1, _) (lb2, _) (ub2, _) -> lb1 < lb2 && ub1 > ub2)) $ \(a, b) ->
    Interval.relate a b == Contains

prop_relate_closed_interval_contains_open_interval_with_same_boundary =
  forAll (arbitrary `suchThat` \(lb, rb) -> lb < rb) $
    \(lb :: Rational, rb) ->
      Interval.relate
        (Interval.interval (Finite lb, Interval.Closed) (Finite rb, Interval.Closed))
        (Interval.interval (Finite lb, Interval.Open) (Finite rb, Interval.Open))
      == Contains

prop_relate_one_singleton_before_another =
  forAll (arbitrary `suchThat` uncurry (<)) $ \(r1 :: Rational, r2) ->
    Interval.relate (Interval.singleton r1) (Interval.singleton r2) == Before

prop_relate_singleton_starts_interval =
  forAll (arbitrary `suchThat` uncurry (<)) $ \(r1 :: Rational, r2) b ->
    Interval.relate (Interval.singleton r1) (Interval.interval (Finite r1, Interval.Closed) (Finite r2, b)) == Starts

prop_relate_singleton_just_before_interval =
  forAll (arbitrary `suchThat` uncurry (<)) $ \(r1 :: Rational, r2) b ->
    Interval.relate (Interval.singleton r1) (Interval.interval (Finite r1, Interval.Open) (Finite r2, b)) == JustBefore

prop_relate_singleton_finishes_interval =
  forAll (arbitrary `suchThat` uncurry (<)) $ \(r1 :: Rational, r2) b ->
    Interval.relate (Interval.singleton r2) (Interval.interval (Finite r1, b) (Finite r2, Interval.Closed)) == Finishes

prop_relate_singleton_just_after_interval =
  forAll (arbitrary `suchThat` uncurry (<)) $ \(r1 :: Rational, r2) b ->
    Interval.relate (Interval.singleton r2) (Interval.interval (Finite r1, b) (Finite r2, Interval.Open)) == JustAfter

{--------------------------------------------------------------------
  Comparison
--------------------------------------------------------------------}

case_lt_all_1 = (a <! b) @?= False
  where
    a, b :: Interval Rational
    a = NegInf <..<= 0
    b = 0 <=..< PosInf

case_lt_all_2 = (a <! b) @?= True
  where
    a, b :: Interval Rational
    a = NegInf <..< 0
    b = 0 <=..< PosInf

case_lt_all_3 = (a <! b) @?= True
  where
    a, b :: Interval Rational
    a = NegInf <..<= 0
    b = 0 <..< PosInf

case_lt_all_4 = (a <! b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = 1 <=..< PosInf

case_lt_some_1 = (a <? b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = NegInf <..<= 0

case_lt_some_2 = (a <? b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <..< PosInf
    b = NegInf <..<= 0

case_lt_some_3 = (a <? b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = NegInf <..< 0

case_lt_some_4 = (a <! b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = 1 <=..< PosInf

case_le_some_1 = (a <=? b) @?= True
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = NegInf <..<= 0

case_le_some_2 = (a <=? b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <..< PosInf
    b = NegInf <..<= 0

case_le_some_3 = (a <=? b) @?= False
  where
    a, b :: Interval Rational
    a = 0 <=..< PosInf
    b = NegInf <..< 0

prop_lt_all_not_refl =
  forAll intervals $ \a -> not (Interval.null a) ==> not (a <! a)

prop_le_some_refl =
  forAll intervals $ \a -> not (Interval.null a) ==> a <=? a

prop_ne_all_not_refl =
  forAll intervals $ \a -> not (Interval.null a) ==> not (a /=! a)

prop_lt_all_singleton =
  forAll arbitrary $ \a ->
  forAll arbitrary $ \b ->
    (a::Rational) < b ==> Interval.singleton a <! Interval.singleton b

prop_lt_all_singleton_2 =
  forAll arbitrary $ \a ->
    not $ Interval.singleton (a::Rational) <! Interval.singleton a

prop_le_all_singleton =
  forAll arbitrary $ \a ->
  forAll arbitrary $ \b ->
    (a::Rational) <= b ==> Interval.singleton a <=! Interval.singleton b

prop_le_all_singleton_2 =
  forAll arbitrary $ \a ->
    Interval.singleton (a::Rational) <=! Interval.singleton a

prop_eq_all_singleton =
  forAll arbitrary $ \a ->
    Interval.singleton (a::Rational) ==! Interval.singleton a

prop_ne_all_singleton =
  forAll arbitrary $ \a ->
  forAll arbitrary $ \b ->
    (a::Rational) /= b ==> Interval.singleton a /=! Interval.singleton b

prop_ne_all_singleton_2 =
  forAll arbitrary $ \a ->
    not $ Interval.singleton (a::Rational) /=! Interval.singleton a

prop_lt_some_singleton =
  forAll arbitrary $ \a ->
  forAll arbitrary $ \b ->
    (a::Rational) < b ==> Interval.singleton a <? Interval.singleton b

prop_lt_some_singleton_2 =
  forAll arbitrary $ \a ->
    not $ Interval.singleton (a::Rational) <? Interval.singleton a

prop_le_some_singleton =
  forAll arbitrary $ \a ->
  forAll arbitrary $ \b ->
    (a::Rational) <= b ==> Interval.singleton a <=? Interval.singleton b

prop_le_some_singleton_2 =
  forAll arbitrary $ \a ->
    Interval.singleton (a::Rational) <=? Interval.singleton a

prop_eq_some_singleton =
  forAll arbitrary $ \a ->
    Interval.singleton (a::Rational) ==? Interval.singleton a

prop_lt_all_empty =
  forAll intervals $ \a -> a <! Interval.empty

prop_lt_all_empty_2 =
  forAll intervals $ \a -> Interval.empty <! a

prop_le_all_empty =
  forAll intervals $ \a -> a <=! Interval.empty

prop_le_all_empty_2 =
  forAll intervals $ \a -> Interval.empty <=! a

prop_eq_all_empty =
  forAll intervals $ \a -> a ==! Interval.empty

prop_ne_all_empty =
  forAll intervals $ \a -> a /=! Interval.empty

prop_lt_some_empty =
  forAll intervals $ \a -> not (a <? Interval.empty)

prop_lt_some_empty_2 =
  forAll intervals $ \a -> not (Interval.empty <? a)

prop_le_some_empty =
  forAll intervals $ \a -> not (a <=? Interval.empty)

prop_le_some_empty_2 =
  forAll intervals $ \a -> not (Interval.empty <=? a)

prop_eq_some_empty =
  forAll intervals $ \a -> not (a ==? Interval.empty)

prop_intersect_le_some =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    not (Interval.null (Interval.intersection a b))
    ==> a <=? b

prop_intersect_eq_some =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    not (Interval.null (Interval.intersection a b))
    ==> a ==? b

prop_le_some_witness =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    case a <=?? b of
      Nothing ->
        forAll arbitrary $ \(x,y) ->
          not (Interval.member x a && Interval.member y b && x <= y)
      Just (x,y) ->
        Interval.member x a .&&. Interval.member y b .&&. x <= y

prop_lt_some_witness =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    case a <?? b of
      Nothing ->
        forAll arbitrary $ \(x,y) ->
          not (Interval.member x a && Interval.member y b && x < y)
      Just (x,y) ->
        Interval.member x a .&&. Interval.member y b .&&. x < y

case_lt_some_witness_test1 = do
  let i1 = 0
      i2 = 0 <=..<= 1
  case i1 <?? i2 of
    Nothing -> assertFailure "should not be Nothing"
    Just (a,b) -> do
      unless (a `Interval.member` i1) $ assertFailure (show a ++ "is not a member of " ++ show i1)
      unless (b `Interval.member` i2) $ assertFailure (show b ++ "is not a member of " ++ show i2)
      unless (a < b) $ assertFailure (show a ++ " < " ++ show b ++ " failed")

prop_eq_some_witness =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    case a ==?? b of
      Nothing ->
        forAll arbitrary $ \x ->
          not (Interval.member x a && Interval.member x b)
      Just (x,y) ->
        Interval.member x a .&&. Interval.member y b .&&. x == y

prop_ne_some_witness =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    case a /=?? b of
      Nothing ->
        forAll arbitrary $ \x ->
        forAll arbitrary $ \y ->
          not (Interval.member x a && Interval.member y b && x /= y)
      Just (x,y) ->
        Interval.member x a .&&. Interval.member y b .&&. x /= y

case_ne_some_witness_test1 = do
  let i1 = 0
      i2 = 0 <=..<= 1
  case i1 /=?? i2 of
    Nothing -> assertFailure "should not be Nothing"
    Just (a,b) -> do
      unless (a `Interval.member` i1) $ assertFailure (show a ++ "is not a member of " ++ show i1)
      unless (b `Interval.member` i2) $ assertFailure (show b ++ "is not a member of " ++ show i2)
      unless (a /= b) $ assertFailure (show a ++ " /= " ++ show b ++ " failed")

case_ne_some_witness_test2 = do
  let i1 = 0 <=..<= 1
      i2 = 1
  case i1 /=?? i2 of
    Nothing -> assertFailure "should not be Nothing"
    Just (a,b) -> do
      unless (a `Interval.member` i1) $ assertFailure (show a ++ "is not a member of " ++ show i1)
      unless (b `Interval.member` i2) $ assertFailure (show b ++ "is not a member of " ++ show i2)
      unless (a /= b) $ assertFailure (show a ++ " /= " ++ show b ++ " failed")

prop_le_some_witness_forget =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    isJust (a <=?? b) == (a <=? b)

prop_lt_some_witness_forget =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    isJust (a <?? b) == (a <? b)

prop_eq_some_witness_forget =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    isJust (a ==?? b) == (a ==? b)

prop_ne_some_witness_forget =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    isJust (a /=?? b) == (a /=? b)

{--------------------------------------------------------------------
  Num
--------------------------------------------------------------------}

prop_scale_empty =
  forAll arbitrary $ \r ->
    Interval.singleton (r::Rational) * Interval.empty == Interval.empty

prop_add_comm =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    a + b == b + a

prop_add_assoc =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    a + (b + c) == (a + b) + c

prop_add_unitL =
  forAll intervals $ \a ->
    Interval.singleton 0 + a == a

prop_add_unitR =
  forAll intervals $ \a ->
    a + Interval.singleton 0 == a

prop_add_member =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    and [ (x+y) `Interval.member` (a+b)
        | x <- maybeToList $ Interval.pickup a
        , y <- maybeToList $ Interval.pickup b
        ]

prop_mult_comm =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    a * b == b * a

prop_mult_assoc =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    a * (b * c) == (a * b) * c

prop_mult_unitL =
  forAll intervals $ \a ->
    Interval.singleton 1 * a == a

prop_mult_unitR =
  forAll intervals $ \a ->
    a * Interval.singleton 1 == a

prop_mult_dist =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
  forAll intervals $ \c ->
    (a * (b + c)) `Interval.isSubsetOf` (a * b + a * c)

prop_mult_empty =
  forAll intervals $ \a ->
    Interval.empty * a == Interval.empty

prop_mult_zero =
  forAll intervals $ \a ->
    not (Interval.null a) ==> Interval.singleton 0 * a ==  Interval.singleton 0

prop_mult_member =
  forAll intervals $ \a ->
  forAll intervals $ \b ->
    and [ (x*y) `Interval.member` (a*b)
        | x <- maybeToList $ Interval.pickup a
        , y <- maybeToList $ Interval.pickup b
        ]

case_mult_test1 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = 1 <=..<= 2
    ival2 = 1 <=..<= 2
    ival3 = 1 <=..<= 4

case_mult_test2 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = 1 <=..<= 2
    ival2 = 1 <..< 2
    ival3 = 1 <..< 4

case_mult_test3 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = 1 <..< 2
    ival2 = 1 <..< 2
    ival3 = 1 <..< 4

case_mult_test4 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = 2 <..< PosInf
    ival2 = 3 <..< PosInf
    ival3 = 6 <..< PosInf

case_mult_test5 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = NegInf <..< (-3)
    ival2 = NegInf <..< (-2)
    ival3 = 6 <..< PosInf

case_mult_test6 = ival1 * ival2 @?= ival3
  where
    ival1 :: Interval Rational
    ival1 = 2 <..< PosInf
    ival2 = NegInf <..< (-2)
    ival3 = NegInf <..< (-4)

prop_abs_signum =
  forAll intervals $ \a ->
    abs (signum a) `Interval.isSubsetOf` (0 <=..<= 1)

prop_negate_negate =
  forAll intervals $ \a ->
    negate (negate a) == a

{--------------------------------------------------------------------
  Fractional
--------------------------------------------------------------------}

prop_recip_singleton =
  forAll arbitrary $ \r ->
    let n = fromIntegral (numerator r)
        d = fromIntegral (denominator r)
    in Interval.singleton n / Interval.singleton d == Interval.singleton (r::Rational)

case_recip_empty =
  recip Interval.empty @?= Interval.empty

case_recip_pos =
  recip pos @?= pos

case_recip_neg =
  recip neg @?= neg

case_recip_test1 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = 2 <=..< PosInf
    i2 = 0 <..<= (1/2)

case_recip_test2 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = 0 <..<= 10
    i2 = (1/10) <=..< PosInf

case_recip_test3 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = -10 <=..< 0
    i2 = NegInf <..<= (-1/10)

case_recip_test4 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = 0 <=..<= 10
    i2 = (1/10) <=..< PosInf

case_recip_test5 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = -10 <=..<= 0
    i2 = NegInf <..<= (-1/10)

case_recip_test6 = recip i1 @?= i2
  where
    i1, i2 :: Interval Rational
    i1 = 0 <=..<= 0
    i2 = Interval.empty

prop_recip =
  forAll intervals $ \a ->
    if 0 `isInteriorPoint` a
    then recip a === Interval.whole
    else recip (recip a) === without0 a

isInteriorPoint :: (Ord a, Show a) => a -> Interval a -> Bool
isInteriorPoint x xs
  = x `Interval.member` xs
  && Finite x /= Interval.lowerBound xs
  && Finite x /= Interval.upperBound xs

without0 :: (Ord a, Num a) => Interval a -> Interval a
without0 xs = case Interval.lowerBound' xs of
  (0, Interval.Closed) ->
    Interval.interval (0, Interval.Open) (Interval.upperBound' xs)
  _ -> case Interval.upperBound' xs of
    (0, Interval.Closed) ->
      Interval.interval (Interval.lowerBound' xs) (0, Interval.Open)
    _ -> xs

{--------------------------------------------------------------------
  Floating
--------------------------------------------------------------------}

prop_exp_singleton = floatingSingleton exp

prop_exp_mid_point = floatingMidPoint exp

case_exp_whole = exp Interval.whole @?= 0 <..< PosInf

case_exp_empty = exp Interval.empty @?= Interval.empty

prop_log_singleton a = a > 0 ==>
  floatingSingleton log a

prop_log_mid_point = floatingMidPoint log . Interval.intersection (0 <..< PosInf)

case_log_whole = log Interval.whole   @?= Interval.whole
case_log_half1 = log (0 <=..< PosInf) @?= Interval.whole
case_log_half2 = log (0 <..< PosInf)  @?= Interval.whole
case_log_zero  = log (0 :: Interval Double) @?= Interval.empty

case_log_empty = log Interval.empty @?= Interval.empty

prop_log_exp a = log (exp a) =~= a

prop_exp_log a = exp (log a) =~= a `Interval.intersection` (0 <..< PosInf)

-------------------------------------------------------------------------------

prop_sqrt_singleton = floatingSingleton sqrt

prop_sqrt_mid_point = floatingMidPoint sqrt . Interval.intersection (0 <=..< PosInf)

case_sqrt_whole = sqrt Interval.whole @?= 0 <=..< PosInf

case_sqrt_empty = sqrt Interval.empty @?= Interval.empty

prop_sqr_sqrt a = sqrt a * sqrt a =~= a `Interval.intersection` (0 <=..< PosInf)

prop_sqrt_sqr a = sqrt (a * a) =~= abs a

-------------------------------------------------------------------------------

prop_pow_singleton_Double_Double a' b' =
  not (isInfinite c || isNaN c) ==>
    Interval.singleton a ** Interval.singleton b =~= Interval.singleton c
  where
    a = min 5 $ max (-5) a'
    b = min 5 $ max (-5) b'
    c = a ** b

prop_pow_singleton_Double_Integer 0 b'
  | b' < 0 = discard
prop_pow_singleton_Double_Integer a' b' =
  Interval.singleton a ** Interval.singleton b =~= Interval.singleton (a ** b)
  where
    a = min 5 $ max (-5) a'
    b = min 5 $ max (-5) $ fromInteger b'

prop_pow_singleton_Integer_Double a' b =
  not (isInfinite c || isNaN c) ==>
    Interval.singleton a ** Interval.singleton b =~= Interval.singleton (a ** b)
  where
    a = fromInteger a'
    c = a ** b

prop_pow_mid_point a' b' = case (Interval.pickup a, Interval.pickup b) of
  (Nothing, _) -> discard
  (_, Nothing) -> discard
  (Just x, Just y) -> let z = x ** y :: Double in not (isInfinite z || isNaN z) ==>
    ioProperty $ do
      x <- try (evaluate (a ** b))
      return $ case x of
        Left LossOfPrecision -> discard
        Right c -> distance z c < Finite (1e-10 * (1 `max` abs z))
  where
    -- for larger intervals the loss of precision becomes exponentially huge
    a = Interval.mapMonotonic (min 5 . max (-5)) a'
    b = Interval.mapMonotonic (min 5 . max (-5)) b'

prop_pow_empty_1 :: Interval Double -> Bool
prop_pow_empty_1 x = Interval.null (Interval.empty ** x)

prop_pow_empty_2 :: Interval Double -> Bool
prop_pow_empty_2 x = Interval.null (x ** Interval.empty)

-------------------------------------------------------------------------------

prop_sin_singleton a =
  distance (sin a :: Double) (sin (Interval.singleton a)) <= 1e-10

prop_sin_mid_point a
  | Interval.isSingleton a = discard
  | otherwise = floatingMidPoint sin a

case_sin_whole = sin Interval.whole @?= -1 <=..<= 1

case_sin_empty = sin Interval.empty @?= Interval.empty

prop_asin_singleton a = floatingSingleton asin (if abs a < 1 then a else recip a)

prop_asin_mid_point = floatingMidPoint asin . Interval.intersection (-1 <=..<= 1)

case_asin_whole = asin Interval.whole @?= Finite (-pi / 2) <=..<= Finite (pi / 2)

case_asin_empty = asin Interval.empty @?= Interval.empty

prop_sin_asin a = sin (asin a) =~= a `Interval.intersection` (-1 <=..<= 1)

-------------------------------------------------------------------------------

prop_cos_singleton a =
  distance (cos a :: Double) (cos (Interval.singleton a)) <= 1e-10

prop_cos_mid_point a
  | Interval.isSingleton a = discard
  | otherwise = floatingMidPoint cos a

case_cos_whole = cos Interval.whole @?= -1 <=..<= 1

case_cos_empty = cos Interval.empty @?= Interval.empty

prop_acos_singleton a = floatingSingleton acos (if abs a < 1 then a else recip a)

prop_acos_mid_point = floatingMidPoint acos . Interval.intersection (-1 <=..<= 1)

case_acos_whole = acos Interval.whole @?= 0 <=..<= Finite pi

case_acos_empty = acos Interval.empty @?= Interval.empty

prop_cos_acos a = cos (acos a) =~= a `Interval.intersection` (-1 <=..<= 1)

-------------------------------------------------------------------------------

prop_tan_singleton a =
  distance (tan a :: Double) (tan (Interval.singleton a)) <= 1e-10

prop_tan_mid_point a = case Interval.pickup a of
  Nothing -> discard
  Just x -> let z = tan x :: Double in not (isInfinite z || isNaN z) ==>
    ioProperty $ do
      x <- try (evaluate (tan a))
      return $ case x of
        Left LossOfPrecision -> discard
        Right c -> distance z c < Finite (1e-10 * (1 `max` abs z))

case_tan_whole = tan Interval.whole @?= Interval.whole

case_tan_empty = tan Interval.empty @?= Interval.empty

prop_atan_singleton = floatingSingleton atan

prop_atan_mid_point = floatingMidPoint atan

case_atan_whole = atan Interval.whole @?= Finite (-pi / 2) <=..<= Finite (pi / 2)

case_atan_empty = atan Interval.empty @?= Interval.empty

prop_tan_atan a = case (Interval.lowerBound a, Interval.upperBound a) of
  (Finite{}, Finite{}) -> tan (atan a) =~= a
  _ -> discard

-------------------------------------------------------------------------------

prop_sinh_singleton = floatingSingleton sinh

prop_sinh_mid_point = floatingMidPoint sinh

case_sinh_whole = sinh Interval.whole @?= Interval.whole

case_sinh_empty = sinh Interval.empty @?= Interval.empty

prop_asinh_singleton = floatingSingleton asinh

prop_asinh_mid_point = floatingMidPoint asinh

case_asinh_whole = asinh Interval.whole @?= Interval.whole

case_asinh_empty = asinh Interval.empty @?= Interval.empty

prop_asinh_sinh a' = asinh (sinh a) =~= a
  where
    -- for larger intervals the loss of precision becomes exponentially huge
    a = Interval.mapMonotonic (min 5 . max (-5)) a'

prop_sinh_asinh a = sinh (asinh a) =~= a

-------------------------------------------------------------------------------

prop_cosh_singleton = floatingSingleton cosh

prop_cosh_mid_point = floatingMidPoint cosh

case_cosh_whole = cosh Interval.whole @?= 1 <=..< PosInf

case_cosh_empty = cosh Interval.empty @?= Interval.empty

prop_acosh_singleton = floatingSingleton acosh

prop_acosh_mid_point = floatingMidPoint acosh . Interval.intersection (1 <=..< PosInf)

case_acosh_whole = acosh Interval.whole @?= 0 <=..< PosInf

case_acosh_empty = acosh Interval.empty @?= Interval.empty

prop_acosh_cosh a' = acosh (cosh a) =~= abs a
  where
    -- for larger intervals the loss of precision becomes exponentially huge
    a = Interval.mapMonotonic (min 5 . max (-5)) a'

prop_cosh_acosh a = cosh (acosh a) =~= a `Interval.intersection` (1 <=..< PosInf)

-------------------------------------------------------------------------------

prop_tanh_singleton a = abs a <= 10 ==>
  floatingSingleton tanh a

prop_tanh_mid_point = floatingMidPoint tanh . Interval.intersection (-5 <=..<= 5)

case_tanh_whole = tanh Interval.whole @?= -1 <..< 1

case_tanh_empty = tanh Interval.empty @?= Interval.empty

prop_atanh_singleton 1    = atanh 1 === Interval.empty
prop_atanh_singleton (-1) = atanh (-1) === Interval.empty
prop_atanh_singleton a    = floatingSingleton atanh (if abs a < 1 then a else recip a)

prop_atanh_mid_point = floatingMidPoint atanh . Interval.intersection (-1 <..< 1)

case_atanh_whole = atanh Interval.whole @?= Interval.whole

case_atanh_empty = atanh Interval.empty @?= Interval.empty

prop_atanh_tanh a' = atanh (tanh a) =~= a
  where
    -- for larger intervals the loss of precision becomes exponentially huge
    a = Interval.mapMonotonic (min 5 . max (-5)) a'

prop_tanh_atanh = uncurry (=~=) . tanhAtanh

case_tanh_atanh_1 = uncurry (@?=) $ tanhAtanh (-1 <=..<= 1)
case_tanh_atanh_2 = uncurry (@?=) $ tanhAtanh (-1 <=..< 1)
case_tanh_atanh_3 = uncurry (@?=) $ tanhAtanh (-1 <..<= 1)
case_tanh_atanh_4 = uncurry (@?=) $ tanhAtanh (-1 <..< 1)

tanhAtanh :: Interval Double -> (Interval Double, Interval Double)
tanhAtanh a = (tanh (atanh a), a `Interval.intersection` (-1 <..< 1))

-------------------------------------------------------------------------------

floatingSingleton :: (forall a. Floating a => a -> a) -> Double -> Property
floatingSingleton f a = Interval.singleton (f a) === f (Interval.singleton a)

distance :: (Ord r, Num r) => r -> Interval r -> Extended r
distance x xs
  | Interval.member x xs = 0
  | otherwise
  = abs (Finite x - Interval.lowerBound xs) `min`
    abs (Finite x - Interval.upperBound xs)

floatingMidPoint :: (forall a. Floating a => a -> a) -> Interval Double -> Property
floatingMidPoint f a = case Interval.pickup a of
  Nothing -> discard
  Just x  -> property $ f x `Interval.member` f a

infix 4 =~=
(=~=) :: Interval Double -> Interval Double -> Property
a =~= b
  | eqPair (Interval.lowerBound' a) (Interval.lowerBound' b)
  , eqPair (Interval.upperBound' a) (Interval.upperBound' b)
  = property True
  | otherwise
  = a === b
  where
    eqPair (x, a) (y, b) = eqExt x y && a == b

    eqExt (Finite x) (Finite y) =
      abs (x - y) < 1e-10 * (1 `max` abs x `max` abs y)
    eqExt x y = x == y

{--------------------------------------------------------------------
  Lattice
--------------------------------------------------------------------}

#ifdef MIN_VERSION_lattices

prop_Lattice_Leq_welldefined =
  forAll intervals $ \a b ->
    a `L.meetLeq` b == a `L.joinLeq` b

prop_top =
  forAll intervals $ \a ->
    a `L.joinLeq` L.top

prop_bottom =
  forAll intervals $ \a ->
    L.bottom `L.joinLeq` a

#else

prop_Lattice_Leq_welldefined = True
prop_top                     = True
prop_bottom                  = True

#endif

{--------------------------------------------------------------------
  Read
--------------------------------------------------------------------}

prop_show_read_invariance =
  forAll intervals $ \i -> do
    i == read (show i)

case_read_old =
  read "interval (Finite (0 % 1), Closed) (PosInf, Open)" @?=
  (Interval.interval (Finite 0, Interval.Closed) (PosInf, Interval.Open) :: Interval Rational)

{--------------------------------------------------------------------
  NFData
--------------------------------------------------------------------}

prop_rnf =
  forAll intervals $ \a ->
    rnf a == ()

{--------------------------------------------------------------------
  Hashable
--------------------------------------------------------------------}

prop_hash =
  forAll intervals $ \i ->
    hash i `seq` True

{- ------------------------------------------------------------------
  Data
------------------------------------------------------------------ -}

case_Data = everywhere f i @?= (1 <=..<= 2 :: Interval Integer)
  where
    i :: Interval Integer
    i = 0 <=..<= 1
    f x
      | Just (y :: Integer) <- cast x = fromJust $ cast (y + 1)
      | otherwise = x

{--------------------------------------------------------------------
  Storable
--------------------------------------------------------------------}

#ifdef MIN_VERSION_quickcheck_classes_base
test_Storable_Int8 = map (uncurry testProperty) $ lawsProperties $
  storableLaws (Proxy :: Proxy (Interval Int8))
test_Storable_Int = map (uncurry testProperty) $ lawsProperties $
  storableLaws (Proxy :: Proxy (Interval Int))
#else
test_Storable_Int8 = []
test_Storable_Int = []
#endif

{--------------------------------------------------------------------
  Generators
--------------------------------------------------------------------}

nonEmptyIntervalPairs
  :: ( (Extended Rational, Interval.Boundary)
    -> (Extended Rational, Interval.Boundary)
    -> (Extended Rational, Interval.Boundary)
    -> (Extended Rational, Interval.Boundary)
    -> Bool)
  -> Gen (Interval Rational, Interval Rational)
nonEmptyIntervalPairs boundariesComparer = ap (fmap (,) intervals) intervals `suchThat`
  (\(i1, i2) ->
    (not . Interval.null $ i1) &&
    (not . Interval.null $ i2) &&
    boundariesComparer
      (Interval.lowerBound' i1)
      (Interval.upperBound' i1)
      (Interval.lowerBound' i2)
      (Interval.upperBound' i2)
  )

{--------------------------------------------------------------------
  Test intervals
--------------------------------------------------------------------}

pos :: Interval Rational
pos = 0 <..< PosInf

neg :: Interval Rational
neg = NegInf <..< 0

nonpos :: Interval Rational
nonpos = NegInf <..<= 0

nonneg :: Interval Rational
nonneg = 0 <=..< PosInf

------------------------------------------------------------------------
-- Test harness

intervalTestGroup = $(testGroupGenerator)
