# syntax=docker/dockerfile:1

# ---- Build stage: compile + publish the web app with the .NET 8 SDK ----
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Restore against the project file first for better layer caching.
COPY MeridianMutual.csproj ./
RUN dotnet restore MeridianMutual.csproj

# Copy the rest of the source and publish. The test project is excluded from
# the web project's compile items (see MeridianMutual.csproj), so publishing the
# web csproj alone is sufficient.
COPY . ./
RUN dotnet publish MeridianMutual.csproj -c Release -o /app /p:UseAppHost=false

# ---- Runtime stage: ASP.NET Core 8 runtime only ----
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app ./

# The app serves plain HTTP (UseHttpsRedirection was removed). Container Apps
# terminates TLS at the ingress; the container listens on 8080.
EXPOSE 8080
ENV ASPNETCORE_HTTP_PORTS=8080

ENTRYPOINT ["dotnet", "MeridianMutual.dll"]
