#lang typed/racket

(require vraid/types)

(require/typed/provide "climate-data.rkt"
                       [#:struct tile-climate-data
                                 ([sunlight : flonum-get]
                                  [temperature : flonum-get]
                                  [humidity : flonum-get]
                                  [precipitation : flonum-get]
                                  [snow-cover : flonum-get]
                                  [temperature-set! : flonum-set!]
                                  [sunlight-set! : flonum-set!]
                                  [humidity-set! : flonum-set!]
                                  [precipitation-set! : flonum-set!]
                                  [snow-cover-set! : flonum-set!])]
                       [#:struct edge-climate-data
                                 ([river-flow : flonum-get]
                                  [air-flow : flonum-get]
                                  [river-flow-set! : flonum-set!]
                                  [air-flow-set! : flonum-set!])]
                       [make-tile-climate-data (Integer -> tile-climate-data)]
                       [make-edge-climate-data (Integer -> edge-climate-data)])
