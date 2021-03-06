#lang typed/racket

(require racket/fixnum
         racket/flonum
         vraid/types
         vraid/typed-array
         vraid/util
         vraid/math
         "grid-structs.rkt"
         "grid-functions.rkt")

(provide n-grid
         subdivided-grid)

(define-type set-grid-index (integer integer integer -> Void))

(struct: mutable-grid
  ([tile-tile-set! : set-grid-index]
   [tile-corner-set! : set-grid-index]
   [tile-edge-set! : set-grid-index]
   [corner-tile-set! : set-grid-index]
   [corner-corner-set! : set-grid-index]
   [corner-edge-set! : set-grid-index]
   [edge-tile-set! : set-grid-index]
   [edge-corner-set! : set-grid-index]
   [grid : grid]))

(define-type flvector-vector (Vectorof FlVector))

(: 0-grid-coordinates flvector-vector)
(define 0-grid-coordinates
  (let* ([x 0.525731112119133606]
         [z 0.850650808352039932]
         [-x (- x)]
         [-z (- z)])
    (vector
     (flvector x 0.0 -z)
     (flvector -x 0.0 -z)
     (flvector x 0.0 z)
     (flvector -x 0.0 z)
     (flvector 0.0 -z -x)
     (flvector 0.0 -z x)
     (flvector 0.0 z -x)
     (flvector 0.0 z x)
     (flvector -z -x 0.0)
     (flvector z -x 0.0)
     (flvector -z x 0.0)
     (flvector z x 0.0))))

(: 0-grid-tile-tiles (Vectorof integer-vector))
(define 0-grid-tile-tiles
  (vector
   (vector 1 6 11 9 4)
   (vector 0 4 8 10 6)
   (vector 3 5 9 11 7)
   (vector 2 7 10 8 5)
   (vector 0 9 5 8 1)
   (vector 2 3 8 4 9)
   (vector 0 1 10 7 11)
   (vector 2 11 6 10 3)
   (vector 1 4 5 3 10)
   (vector 0 11 2 5 4)
   (vector 1 8 3 7 6)
   (vector 0 6 7 2 9)))

(: allocate-grid (Natural flvector-vector -> mutable-grid))
(define (allocate-grid subdivision-level tile-coordinates)
  (let* ([tile-count (subdivision-level-tile-count subdivision-level)]
         [corner-count (subdivision-level-corner-count subdivision-level)]
         [edge-count (subdivision-level-edge-count subdivision-level)]
         [empty-coordinates (lambda: ([n : Integer]) (flvector))]
         [tile-get (lambda: ([f : (Integer -> Integer)])
                     (lambda: ([n : Integer]
                               [i : Integer])
                       (f (+ (* 6 n) (modulo i (tile-edge-count n))))))]
         [fixed-get (lambda: ([count : Natural]
                              [f : (Integer -> Integer)])
                      (lambda: ([n : Integer]
                                [i : Integer])
                        (f (+ (* count n) (modulo i count)))))]
         [corner-get (curry fixed-get 3)]
         [edge-get (curry fixed-get 2)]
         [tile-set! (lambda: ([f : (Integer Integer -> Void)])
                      (lambda: ([n : Integer]
                                [i : Integer]
                                [k : Integer])
                        (f (+ (* 6 n) (modulo i (tile-edge-count n))) k)))]
         [fixed-set! (lambda: ([count : Natural]
                               [f : (Integer Integer -> Void)])
                       (lambda: ([n : Integer]
                                 [i : Integer]
                                 [k : Integer])
                         (f (+ (* count n) (modulo i count)) k)))]
         [corner-set! (curry fixed-set! 3)]
         [edge-set! (curry fixed-set! 2)])
    (let-values
        ([(tile-tile tile-tile-set!) (make-int-array (* 6 tile-count))]
         [(tile-corner tile-corner-set!) (make-int-array (* 6 tile-count))]
         [(tile-edge tile-edge-set!) (make-int-array (* 6 tile-count))]
         [(corner-tile corner-tile-set!) (make-int-array (* 3 corner-count))]
         [(corner-corner corner-corner-set!) (make-int-array (* 3 corner-count))]
         [(corner-edge corner-edge-set!) (make-int-array (* 3 corner-count))]
         [(edge-tile edge-tile-set!) (make-int-array (* 2 edge-count))]
         [(edge-corner edge-corner-set!) (make-int-array (* 2 edge-count))])
      (for ([n (* 6 tile-count)])
        (tile-corner-set! n -1)
        (tile-edge-set! n -1))
      (mutable-grid
       (tile-set! tile-tile-set!)
       (tile-set! tile-corner-set!)
       (tile-set! tile-edge-set!)
       (corner-set! corner-tile-set!)
       (corner-set! corner-corner-set!)
       (corner-set! corner-edge-set!)
       (edge-set! edge-tile-set!)
       (edge-set! edge-corner-set!)
       (grid
        subdivision-level
        (lambda: ([n : integer]) (vector-ref tile-coordinates n))
        empty-coordinates
        (tile-get tile-tile)
        (tile-get tile-corner)
        (tile-get tile-edge)
        (corner-get corner-tile)
        (corner-get corner-corner)
        (corner-get corner-edge)
        (edge-get edge-tile)
        (edge-get edge-corner))))))

(: make-corner-coordinates (grid -> flvector-vector))
(define (make-corner-coordinates grid)
  (build-vector
   (grid-corner-count grid)
   (lambda: ([n : integer])
     (flvector3-normal
      (apply flvector3-sum
             (map (lambda: ([i : integer])
                    ((grid-tile-coordinates grid) i))
                  (grid-corner-tile-list grid n)))))))

(: grid-with-corner-coordinates (grid -> grid))
(define (grid-with-corner-coordinates g)
  (let ([corners (make-corner-coordinates g)])
    (grid
     (grid-subdivision-level g)
     (grid-tile-coordinates g)
     (lambda: ([n : integer])
       (vector-ref corners n))
     (grid-tile-tile g)
     (grid-tile-corner g)
     (grid-tile-edge g)
     (grid-corner-tile g)
     (grid-corner-corner g)
     (grid-corner-edge g)
     (grid-edge-tile g)
     (grid-edge-corner g))))

(: complete-grid (mutable-grid -> grid))
(define (complete-grid mgrid)
  (let ([grid (mutable-grid-grid mgrid)])
    (: make-corners! (integer integer integer -> Void))
    (define (make-corners! tile i corner)
      (: empty-corner? (integer integer -> Boolean))
      (define (empty-corner? tile i)
        (= -1 ((grid-tile-corner grid) tile i)))
      (define (make-corner!)
        (let* ([tiles (vector tile
                              ((grid-tile-tile grid) tile (- i 1))
                              ((grid-tile-tile grid) tile i))])
          (for ([n corner-edge-count])
            (let ([t (vector-ref tiles n)])
              ((mutable-grid-corner-tile-set! mgrid) corner n t)
              ((mutable-grid-tile-corner-set! mgrid) t
                                                     (grid-tile-tile-position grid t (vector-ref tiles (modulo (- n 1) corner-edge-count)))
                                                     corner)))
          (void)))
      (if (= tile (grid-tile-count grid))
          (void)
          (if (= i (tile-edge-count tile))
              (make-corners! (+ 1 tile) 0 corner)
              (if (empty-corner? tile i)
                  (begin
                    (make-corner!)
                    (make-corners! tile (+ 1 i) (+ 1 corner)))
                  (make-corners! tile (+ 1 i) corner)))))
    (: make-edges! (integer integer integer -> Void))
    (define (make-edges! tile i edge)
      (: empty-edge? (integer integer -> Boolean))
      (define (empty-edge? tile i)
        (= -1 ((grid-tile-edge grid) tile i)))
      (define tile-edge-set! (mutable-grid-tile-edge-set! mgrid))
      (define edge-tile-set! (mutable-grid-edge-tile-set! mgrid))
      (define edge-corner-set! (mutable-grid-edge-corner-set! mgrid))
      (define corner-edge-set! (mutable-grid-corner-edge-set! mgrid))
      (define corner-corner-set! (mutable-grid-corner-corner-set! mgrid))
      (: make-edge! (integer -> Void))
      (define (make-edge! i)
        (let* (
               [tiles (vector tile ((grid-tile-tile grid) tile i))]
               [corners (build-vector 2 (lambda: ([n : integer])
                                          ((grid-tile-corner grid) tile (+ i n))))])
          (for ([n 2])
            (let* ([tile (vector-ref tiles n)]
                   [corner (vector-ref corners n)]
                   [pos (grid-tile-tile-position grid
                                                 (vector-ref tiles n)
                                                 (vector-ref tiles (- 1 n)))]
                   [corner-pos (grid-corner-tile-position grid corner tile)])
              (tile-edge-set! tile pos edge)
              (edge-tile-set! edge n tile)
              (edge-corner-set! edge n corner)
              (corner-edge-set! corner corner-pos edge)
              (corner-corner-set! corner corner-pos (vector-ref corners (- 1 n)))
              (void)))))
      
      (if (= tile (grid-tile-count grid))
          (void)
          (if (= i (tile-edge-count tile))
              (make-edges! (+ 1 tile) 0 edge)
              (if (empty-edge? tile i)
                  (begin
                    (make-edge! i)
                    (make-edges! tile (+ i 1) (+ 1 edge)))
                  (make-edges! tile (+ 1 i) edge)))))
    (make-corners! 0 0 0)
    (make-edges! 0 0 0)
    (grid-with-corner-coordinates grid)))

(: 0-grid grid)
(define 0-grid
  (let* ([mgrid (allocate-grid 0 0-grid-coordinates)]
         [grid (mutable-grid-grid mgrid)])
    (for ([n (grid-tile-count grid)])
      (for ([i 5])
        ((mutable-grid-tile-tile-set! mgrid) n i (vector-ref (vector-ref 0-grid-tile-tiles n) i))))
    (complete-grid mgrid)))

(: make-tile-coordinates (grid -> flvector-vector))
(define (make-tile-coordinates grid)
  (let* ([tile-count (grid-tile-count grid)]
         [corner-count (grid-corner-count grid)]
         [total (+ tile-count corner-count)])
    (build-vector total
                  (lambda: ([n : integer])
                    (if (< n tile-count)
                        ((grid-tile-coordinates grid) n)
                        ((grid-corner-coordinates grid) (- n tile-count)))))))

(: subdivided-grid (grid -> grid))
(define (subdivided-grid g)
  (let* ([mgrid (allocate-grid (+ 1 (grid-subdivision-level g)) (make-tile-coordinates g))]
         [grid (mutable-grid-grid mgrid)]
         [tile-count (grid-tile-count g)])
    (: connect-tiles! (-> Void))
    (define (connect-tiles!)
      (for ([n tile-count])
        (for ([i (tile-edge-count n)])
          ((mutable-grid-tile-tile-set! mgrid) n i (+ tile-count ((grid-tile-corner g) n i)))))
      (for ([n (grid-corner-count g)])
        (for ([i corner-edge-count])
          ((mutable-grid-tile-tile-set! mgrid) (+ n tile-count) (* 2 i) (+ tile-count ((grid-corner-corner g) n i)))
          ((mutable-grid-tile-tile-set! mgrid) (+ n tile-count) (+ 1 (* 2 i)) ((grid-corner-tile g) n i))))
      (void))
    (connect-tiles!)
    (complete-grid mgrid)))

(: n-grid (Nonnegative-Fixnum -> grid))
(define (n-grid n)
  (if (zero? n)
      0-grid
      (subdivided-grid (n-grid (- n 1)))))
