# RatarLoader
A kernel loader that follows a kernel boot protocol to start your OS kernel. You can use it to boot any kernel – as long as it supports this protocol and meets the kernel's boot requirements.

Currently, this loader is far from perfect. Its assembly code is obscure and hard to read, and its author is a young Chinese developer – so most comments are in Chinese, and even the few English ones are hardly comprehensible. Nevertheless, that doesn't stop us from making it highly extensible and hardware‑adaptable.

The compiler options：nasm -f bin Loader.asm -l loader.map -Ox
