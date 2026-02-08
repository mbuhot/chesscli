import { toList } from "../../gleam.mjs";

export function shuffle_list(list) {
  const arr = list.toArray();
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return toList(arr);
}
