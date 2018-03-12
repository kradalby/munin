# TODO

* Bug
  - Reading state from directory concurrently is not working properly
* Compare state
  - Implement remove from remove diff
  - Use added diff to write
    * Diff has to contain mor information, as it removes entries to things not in diff
* Dont create scaled photo bigger than original
* Look into how handling landscape, standing photos should be done
* Symlink handling does ofc not work when we sync to server

* People and Keyword
  - Bubble every keyword from the leaf nodes to the top
  - Keyword/People json that describes all pictures with the given keyword blow the given node
  - Link keyword json from album
