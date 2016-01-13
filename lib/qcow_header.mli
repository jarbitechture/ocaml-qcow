(*
 * Copyright (C) 2015 David Scott <dave@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

module Version : sig
  type t = [
    | `One
    | `Two
    | `Three
  ] with sexp

  include Qcow_s.SERIALISABLE with type t := t
end

module CryptMethod : sig
  type t = [ `Aes | `None ] with sexp

  include Qcow_s.SERIALISABLE with type t := t
end

type offset = int64
(** Offset within the image *)

type extension = {
  dirty: bool;
  corrupt: bool;
  compatible_features: int64;
  autoclear_features: int64;
  refcount_order: int32;
  header_length: int32;
} with sexp

type t = {
  version: Version.t;
  backing_file_offset: offset;    (** offset of the backing file path *)
  backing_file_size: int32;       (** length of the backing file path *)
  cluster_bits: int32;            (** a cluster is 2 ** cluster_bits in size *)
  size: int64;                    (** virtual size of the image *)
  crypt_method: CryptMethod.t;
  l1_size: int32;                 (** number of 8-byte entries in the L1 table *)
  l1_table_offset: offset;        (** offset of the L1 table *)
  refcount_table_offset: offset;  (** offset of the refcount table *)
  refcount_table_clusters: int32; (** size of the refcount table in clusters *)
  nb_snapshots: int32;            (** the number of internal snapshots *)
  snapshots_offset: offset;       (** offset of the snapshot header *)
  extension: extension option;    (** for version 3 or higher *)
} with sexp
(** The qcow2 header *)

val refcounts_per_cluster: t -> int64
(** The number of 16-bit reference counts per cluster *)

val max_refcount_table_size: t -> int64
(** Compute the maximum size of the refcount table *)

val l2_tables_required: cluster_bits:int -> int64 -> int64
(** Compute the number of L2 tables required for this size of image *)

include Qcow_s.SERIALISABLE with type t := t

include Qcow_s.PRINTABLE with type t := t

include Set.OrderedType with type t := t
