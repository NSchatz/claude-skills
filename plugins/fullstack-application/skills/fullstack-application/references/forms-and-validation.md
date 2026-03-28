---
title: Forms and Validation
weight: 11
---

# Forms and Validation

This reference covers React Hook Form with Zod validation, multi-step forms, file upload forms, server error mapping, and form accessibility.

## Table of Contents

- [Setup](#setup)
- [Basic Form Pattern](#basic-form-pattern)
- [FormField Component](#formfield-component)
- [Server Error Mapping](#server-error-mapping)
- [Multi-Step Forms](#multi-step-forms)
- [File Upload Forms](#file-upload-forms)
- [Shared Validation Schemas](#shared-validation-schemas)

---

## Setup

```bash
pnpm add react-hook-form @hookform/resolvers zod
```

---

## Basic Form Pattern

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCreateUserMutation } from '@/store/api/usersApi';

const userSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'At least 8 characters')
    .regex(/[A-Z]/, 'Must contain an uppercase letter')
    .regex(/[0-9]/, 'Must contain a number'),
});

type UserFormData = z.infer<typeof userSchema>;

export function UserForm() {
  const [createUser, { isLoading }] = useCreateUserMutation();

  const { register, handleSubmit, formState: { errors }, setError, reset } =
    useForm<UserFormData>({ resolver: zodResolver(userSchema) });

  const onSubmit = async (data: UserFormData) => {
    try {
      await createUser(data).unwrap();
      reset();
    } catch (err) {
      if (isApiValidationError(err)) {
        for (const [field, message] of Object.entries(err.data.errors)) {
          setError(field as keyof UserFormData, { message });
        }
      } else {
        setError('root', { message: 'An unexpected error occurred' });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      {errors.root && <div role="alert" className="text-red-600 mb-4">{errors.root.message}</div>}

      <FormField label="Email" error={errors.email?.message}>
        <input {...register('email')} type="email"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined} />
      </FormField>

      <FormField label="Password" error={errors.password?.message}>
        <input {...register('password')} type="password"
          aria-invalid={!!errors.password}
          aria-describedby={errors.password ? 'password-error' : undefined} />
      </FormField>

      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Saving...' : 'Create'}
      </button>
    </form>
  );
}
```

---

## FormField Component

Reusable wrapper that handles label-input association and error display:

```tsx
interface FormFieldProps {
  label: string;
  error?: string;
  children: React.ReactNode;
  required?: boolean;
}

export function FormField({ label, error, children, required }: FormFieldProps) {
  const id = label.toLowerCase().replace(/\s+/g, '-');

  return (
    <div className="mb-4">
      <label htmlFor={id} className="block font-medium mb-1">
        {label}
        {required && <span aria-hidden="true" className="text-red-500 ml-1">*</span>}
        {required && <span className="sr-only">(required)</span>}
      </label>
      {children}
      {error && (
        <p id={`${id}-error`} role="alert" className="text-red-600 text-sm mt-1">
          {error}
        </p>
      )}
    </div>
  );
}
```

---

## Server Error Mapping

When the API returns validation errors (RFC 7807 format from `api-design.md`), map them back to form fields:

```ts
function isApiValidationError(err: unknown): err is { data: { errors: FieldError[] } } {
  return typeof err === 'object' && err !== null && 'data' in err
    && typeof (err as any).data === 'object' && 'errors' in (err as any).data;
}

// In onSubmit:
catch (err) {
  if (isApiValidationError(err)) {
    for (const { field, message } of err.data.errors) {
      setError(field as keyof FormData, { message });
    }
  }
}
```

---

## Multi-Step Forms

Each step has its own Zod schema. Validate only the current step before advancing.

```tsx
import { useForm, FormProvider } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useState, useCallback } from 'react';

const step1Schema = z.object({
  firstName: z.string().min(1, 'Required'),
  lastName: z.string().min(1, 'Required'),
});
const step2Schema = z.object({
  address: z.string().min(1, 'Required'),
  city: z.string().min(1, 'Required'),
  zip: z.string().regex(/^\d{5}$/, 'Invalid ZIP'),
});

const fullSchema = step1Schema.merge(step2Schema);
type FullFormData = z.infer<typeof fullSchema>;

const stepFields: (keyof FullFormData)[][] = [
  ['firstName', 'lastName'],
  ['address', 'city', 'zip'],
];

export function MultiStepForm() {
  const [step, setStep] = useState(0);
  const methods = useForm<FullFormData>({
    resolver: zodResolver(fullSchema),
    mode: 'onTouched',
  });

  const goNext = useCallback(async () => {
    const valid = await methods.trigger(stepFields[step]);
    if (valid) setStep((s) => s + 1);
  }, [step, methods]);

  const goBack = useCallback(() => setStep((s) => Math.max(s - 1, 0)), []);

  return (
    <FormProvider {...methods}>
      <form onSubmit={methods.handleSubmit(onSubmit)}>
        <nav aria-label="Form progress">
          <ol className="flex gap-4 mb-6">
            {['Personal', 'Address'].map((label, i) => (
              <li key={label} aria-current={i === step ? 'step' : undefined}
                className={i === step ? 'font-bold' : 'text-gray-400'}>
                {label}
              </li>
            ))}
          </ol>
        </nav>

        {step === 0 && <StepPersonal />}
        {step === 1 && <StepAddress />}

        <div className="flex gap-4 mt-6">
          {step > 0 && <button type="button" onClick={goBack}>Back</button>}
          {step < stepFields.length - 1
            ? <button type="button" onClick={goNext}>Next</button>
            : <button type="submit">Submit</button>}
        </div>
      </form>
    </FormProvider>
  );
}
```

---

## File Upload Forms

See `file-uploads.md` for the S3 backend. Here's the frontend form pattern:

```tsx
const MAX_SIZE = 5 * 1024 * 1024;
const ACCEPTED_TYPES = ['image/png', 'image/jpeg', 'application/pdf'];

const uploadSchema = z.object({
  title: z.string().min(1, 'Required'),
  file: z.instanceof(FileList)
    .refine((f) => f.length === 1, 'File is required')
    .refine((f) => f[0]?.size <= MAX_SIZE, 'Max 5MB')
    .refine((f) => ACCEPTED_TYPES.includes(f[0]?.type), 'Unsupported type'),
});

export function FileUploadForm() {
  const [uploadFile, { isLoading }] = useUploadFileMutation();
  const [progress, setProgress] = useState(0);

  const { register, handleSubmit, formState: { errors }, reset } =
    useForm({ resolver: zodResolver(uploadSchema) });

  const onSubmit = async (data: z.infer<typeof uploadSchema>) => {
    const formData = new FormData();
    formData.append('title', data.title);
    formData.append('file', data.file[0]);

    await uploadFile({ body: formData,
      onUploadProgress: (e: ProgressEvent) => setProgress(Math.round((e.loaded / e.total) * 100)),
    }).unwrap();
    reset();
    setProgress(0);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} encType="multipart/form-data">
      <FormField label="Title" error={errors.title?.message}>
        <input {...register('title')} />
      </FormField>

      <FormField label="File" error={errors.file?.message as string}>
        <input {...register('file')} type="file" accept={ACCEPTED_TYPES.join(',')} />
      </FormField>

      {isLoading && (
        <div role="progressbar" aria-valuenow={progress} aria-valuemin={0} aria-valuemax={100}
          aria-label="Upload progress" className="h-2 bg-gray-200 rounded">
          <div className="h-full bg-blue-600 rounded" style={{ width: `${progress}%` }} />
        </div>
      )}

      <button type="submit" disabled={isLoading}>
        {isLoading ? `Uploading ${progress}%...` : 'Upload'}
      </button>
    </form>
  );
}
```

---

## Shared Validation Schemas

Put validation schemas in `packages/shared` so both frontend and backend use the same rules:

```ts
// packages/shared/src/schemas/user.schema.ts
import { z } from 'zod';

export const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).regex(/[A-Z]/).regex(/[0-9]/),
  name: z.string().min(1).max(100),
});

export type CreateUserDto = z.infer<typeof createUserSchema>;
```

Frontend uses it with React Hook Form. Backend uses it with a Zod validation pipe or converts to class-validator DTOs.
