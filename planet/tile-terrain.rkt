#lang typed/racket

(provide (all-defined-out))

(require vraid/types
         "planet-structs.rkt")

(: tile-water-depth (planet index -> Flonum))
(define (tile-water-depth p n)
  (- (tile-water-level p n)
     (tile-elevation p n)))

(: tile-water? (planet index -> Boolean))
(define (tile-water? p n)
  (< (tile-elevation p n) (tile-water-level p n)))

(: tile-land? (planet index -> Boolean))
(define (tile-land? p n)
  (not (tile-water? p n)))

(: tile-ice-cover (planet index -> Flonum))
(define (tile-ice-cover p n)
  0.0)

(: tile-vegetation-cover (planet index -> Flonum))
(define (tile-vegetation-cover p n)
  0.0)

(: tile-surface-friction (planet index -> Flonum))
(define (tile-surface-friction p n)
  (* 0.002 (if (tile-land? p n)
      0.000045
      0.000040)))