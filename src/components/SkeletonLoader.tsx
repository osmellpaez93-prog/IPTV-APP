import { clsx } from "clsx";

export function Skeleton({ className }: { className?: string }) {
  return <div className={clsx("skeleton rounded-lg", className)} />;
}

export function ChannelCardSkeleton() {
  return (
    <div className="flex items-center gap-3 p-3 rounded-lg bg-bg-card">
      <Skeleton className="w-12 h-12 rounded-md shrink-0" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-3/4" />
        <Skeleton className="h-3 w-1/2" />
      </div>
    </div>
  );
}

export function PosterSkeleton() {
  return <Skeleton className="aspect-[2/3] w-full" />;
}
