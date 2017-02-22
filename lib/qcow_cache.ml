(*
 * Copyright (C) 2017 David Scott <dave@recoil.org>
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
open Qcow_types

let src =
  let src = Logs.Src.create "qcow" ~doc:"qcow2-formatted BLOCK device" in
  Logs.Src.set_level src (Some Logs.Info);
  src

module Log = (val Logs.src_log src : Logs.LOG)

type t = {
  read_cluster: Cluster.t -> (Cstruct.t, Mirage_block.error) result Lwt.t;
  write_cluster: Cluster.t -> Cstruct.t -> (unit, Mirage_block.write_error) result Lwt.t;
  mutable clusters: Cstruct.t Cluster.Map.t;
}

let create ~read_cluster ~write_cluster () =
  let clusters = Cluster.Map.empty in
  { read_cluster; write_cluster; clusters }

let read t cluster =
  if Cluster.Map.mem cluster t.clusters then begin
    let data = Cluster.Map.find cluster t.clusters in
    Lwt.return (Ok data)
  end else begin
    let open Lwt.Infix in
    t.read_cluster cluster
    >>= function
    | Error e -> Lwt.return (Error e)
    | Ok data ->
      t.clusters <- Cluster.Map.add cluster data t.clusters;
      Lwt.return (Ok data)
  end

let write t cluster data =
  if not (Cluster.Map.mem cluster t.clusters) then begin
    Log.err (fun f -> f "Cache.write %s: cluster is nolonger in cache, so update will be dropped" (Cluster.to_string cluster));
    assert false
  end;
  t.clusters <- Cluster.Map.add cluster data t.clusters;
  t.write_cluster cluster data

let remove t cluster =
  if Cluster.Map.mem cluster t.clusters
  then Printf.fprintf stderr "Dropping cache for cluster %s\n" (Cluster.to_string cluster);
  t.clusters <- Cluster.Map.remove cluster t.clusters

module Debug = struct
  let assert_not_cached t cluster =
    if Cluster.Map.mem cluster t.clusters then begin
      Printf.fprintf stderr "Cluster %s still in the metadata cache\n" (Cluster.to_string cluster);
      assert false
    end
  let all_cached_clusters t =
    Cluster.Map.fold (fun cluster _ set ->
      Cluster.IntervalSet.(add (Interval.make cluster cluster) set)
    ) t.clusters Cluster.IntervalSet.empty
end
