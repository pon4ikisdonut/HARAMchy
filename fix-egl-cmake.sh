#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

# Create custom FindOpenGL module that properly creates imported targets
mkdir -p "$LFS/usr/share/cmake/Modules"
cat > "$LFS/usr/share/cmake/Modules/FindOpenGL.cmake" << "CMEOF"
# Custom FindOpenGL that creates OpenGL::EGL target
# First try the standard module
find_path(OPENGL_INCLUDE_DIR GL/gl.h PATHS /usr/include)
find_library(OPENGL_gl_LIBRARY NAMES GL PATHS /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu /usr/lib64)
find_library(OPENGL_egl_LIBRARY NAMES EGL PATHS /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu /usr/lib64)
find_library(OPENGL_glx_LIBRARY NAMES GLX PATHS /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu /usr/lib64)
find_library(OPENGL_opengl_LIBRARY NAMES OpenGL PATHS /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu /usr/lib64)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenGL
  REQUIRED_VARS OPENGL_gl_LIBRARY OPENGL_INCLUDE_DIR
  HANDLE_COMPONENTS)

if(OpenGL_FOUND)
  if(NOT TARGET OpenGL::OpenGL)
    add_library(OpenGL::OpenGL UNKNOWN IMPORTED)
    set_target_properties(OpenGL::OpenGL PROPERTIES
      IMPORTED_LOCATION "${OPENGL_gl_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${OPENGL_INCLUDE_DIR}")
  endif()
  if(NOT TARGET OpenGL::GL)
    add_library(OpenGL::GL UNKNOWN IMPORTED)
    set_target_properties(OpenGL::GL PROPERTIES
      IMPORTED_LOCATION "${OPENGL_gl_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${OPENGL_INCLUDE_DIR}")
  endif()
  if(NOT TARGET OpenGL::EGL)
    add_library(OpenGL::EGL UNKNOWN IMPORTED)
    set_target_properties(OpenGL::EGL PROPERTIES
      IMPORTED_LOCATION "${OPENGL_egl_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${OPENGL_INCLUDE_DIR}")
  endif()
  if(NOT TARGET OpenGL::GLX)
    add_library(OpenGL::GLX UNKNOWN IMPORTED)
    if(OPENGL_glx_LIBRARY)
      set_target_properties(OpenGL::GLX PROPERTIES
        IMPORTED_LOCATION "${OPENGL_glx_LIBRARY}")
    endif()
  endif()
  set(OPENGL_LIBRARIES ${OPENGL_gl_LIBRARY})
  if(OPENGL_egl_LIBRARY)
    list(APPEND OPENGL_LIBRARIES ${OPENGL_egl_LIBRARY})
  endif()
endif()

mark_as_advanced(OPENGL_INCLUDE_DIR OPENGL_gl_LIBRARY OPENGL_egl_LIBRARY OPENGL_glx_LIBRARY OPENGL_opengl_LIBRARY)
CMEOF

echo "Custom FindOpenGL.cmake written"
'
